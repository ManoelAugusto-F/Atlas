# Teams Toolkit - Modulo Atlas para Automacao de Microsoft Teams
# Conforme com Windows PowerShell 5.1 e PowerShell Core 7
# Codificacao estrita: ASCII puro para manter parser funcional

$Global:AtlasLoadedModules = $Global:AtlasLoadedModules | Where-Object { $_ -ne "Teams" }
$Global:AtlasLoadedModules += "Teams"

function Get-TeamsStatus {
    <#
    .SYNOPSIS
        Valida a instalacao e execucao do Microsoft Teams clássico/moderno na maquina.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Analisando estado de execucao do Microsoft Teams..."
    $classicTeamsInstalled = $false
    $modernTeamsInstalled = $false
    $procRunning = $false

    # Checa processos ativos do Teams (antigo: Teams.exe, moderno: msteams.exe)
    try {
        $p1 = Get-Process -Name "Teams" -ErrorAction SilentlyContinue
        $p2 = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue
        $p3 = Get-Process -Name "msteams" -ErrorAction SilentlyContinue
        if ($p1 -or $p2 -or $p3) {
            $procRunning = $true
        }
    } catch {}

    # Checa caminhos comuns de arquivos de instalacao (Windows)
    if ($IsWindows -or ($env:OS -like "*Windows*")) {
        $classicPath = "$env:LocalAppData\Microsoft\Teams\current\Teams.exe"
        if (Test-Path $classicPath) {
            $classicTeamsInstalled = $true
        }

        # Teams moderno é um appx empacotado, checa caminhos da pasta WindowsApps ou caminhos comuns de appx
        $modernPath = "$env:ProgramFiles\WindowsApps\MSTeams*"
        # No PS, buscar com wildcards pode dar falha de permissao, entao tentamos ler via Get-AppxPackage se estiver em modo Windows PowerShell nativo
        if (Get-Command "Get-AppxPackage" -ErrorAction SilentlyContinue) {
            try {
                $pkg = Get-AppxPackage -Name "MSTeams" -ErrorAction SilentlyContinue
                if ($pkg) {
                    $modernTeamsInstalled = $true
                }
            } catch {}
        }
    }

    $ret = [PSCustomObject]@{
        ClassicInstalled = $classicTeamsInstalled
        ModernInstalled  = $modernTeamsInstalled
        ProcessRunning   = $procRunning
    }

    Write-Log -Level "INFO" -Message "Teams verificado - Classico: $classicTeamsInstalled, Moderno: $modernTeamsInstalled, Em Execucao: $procRunning"
    return $ret
}

function Clear-TeamsCache {
    <#
    .SYNOPSIS
        Limpa os arquivos temporarios e caches do MS Teams.
    .DESCRIPTION
        Remove pastas de cache tanto para o Teams Classico (AppData\Roaming\Microsoft\Teams)
        quanto do Teams Moderno (LocalPackages\MSTeams).
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Iniciando limpeza de cache do Microsoft Teams..."

    # Garante fechamento do processo antes da limpeza
    $status = Get-TeamsStatus
    if ($status.ProcessRunning) {
        Write-Log -Level "WARN" -Message "Processo do Teams esta ativo. Fechando processos para limpar cache..."
        try {
            Stop-Process -Name "Teams" -Force -ErrorAction SilentlyContinue
            Stop-Process -Name "ms-teams" -Force -ErrorAction SilentlyContinue
            Stop-Process -Name "msteams" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        } catch {
            Write-Log -Level "ERROR" -Message "Falha ao interromper processos do Teams."
        }
    }

    $clearedDirectories = @()

    if ($IsWindows -or ($env:OS -like "*Windows*")) {
        # 1. Caminho classico: %appdata%\Microsoft\Teams
        $classicCacheDir = "$env:AppData\Microsoft\Teams"
        if (Test-Path $classicCacheDir) {
            Write-Log -Level "INFO" -Message "Limpando pasta do Teams Classico: $classicCacheDir"
            $subFolders = @("Cache", "databases", "GPUCache", "IndexedDB", "Local Storage", "tmp")
            foreach ($sub in $subFolders) {
                # Usa Join-Path aninhado de dois em dois para compatibilidade com PS 5.1
                $target = Join-Path -Path $classicCacheDir -ChildPath $sub
                if (Test-Path $target) {
                    try {
                        Remove-Item -Path "$target\*" -Recurse -Force -ErrorAction SilentlyContinue
                        $clearedDirectories += $target
                    } catch {}
                }
            }
        }

        # 2. Caminho moderno: %localappdata%\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams
        $modernCacheDir = "$env:LocalAppData\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"
        if (Test-Path $modernCacheDir) {
            Write-Log -Level "INFO" -Message "Limpando pasta do Teams Moderno: $modernCacheDir"
            try {
                Remove-Item -Path "$modernCacheDir\*" -Recurse -Force -ErrorAction SilentlyContinue
                $clearedDirectories += $modernCacheDir
            } catch {
                Write-Log -Level "WARN" -Message "Falha ao limpar pasta moderna completa: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Log -Level "INFO" -Message "Operacao nao-Windows. Ignorando delecoes fisicas de cache."
    }

    if ($clearedDirectories.Count -gt 0) {
        Write-Log -Level "INFO" -Message "Caches do Teams limpados com sucesso."
        return $true
    } else {
        Write-Log -Level "INFO" -Message "Nenhum cache do Teams detectado para limpeza."
        return $false
    }
}

function Restart-TeamsSafe {
    <#
    .SYNOPSIS
        Reinicia o Teams com confirmacao do usuario.
    #>
    [CmdletBinding()]
    param()

    $status = Get-TeamsStatus
    if (!($status.ProcessRunning)) {
        Write-Host "Teams nao esta em execucao." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Confirma o reinicio do Microsoft Teams? (S/N): " -NoNewline
    $ans = Read-Host
    if ($ans -notmatch "^[sS]") {
        Write-Log -Level "INFO" -Message "Reinicio do Teams cancelado."
        return
    }

    Write-Log -Level "INFO" -Message "Encerrando Teams..."
    try {
        Stop-Process -Name "Teams", "ms-teams", "msteams" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "Teams foi encerrado e sera reiniciado." -ForegroundColor Green
        Write-Log -Level "INFO" -Message "Teams reiniciado."
        Write-AtlasLog -Nivel INFO -Modulo "Teams" -Acao "Correcao comum" -Resultado "Sucesso"
    } catch {
        Write-Host "Erro ao reiniciar Teams: $_" -ForegroundColor Red
        Write-Log -Level "ERROR" -Message "Erro ao reiniciar Teams: $_"
        Write-AtlasLog -Nivel ERROR -Modulo "Teams" -Acao "Correcao comum" -Resultado "Falha"
    }
}

function Clear-TeamsCacheSafe {
    <#
    .SYNOPSIS
        Limpa o cache do Teams com confirmacao e encerramento seguro.
    #>
    [CmdletBinding()]
    param()

    if (-not ($IsWindows -or ($env:OS -like "*Windows*"))) {
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Deseja limpar o cache do Microsoft Teams?" -ForegroundColor Yellow
    Write-Host "Isso encerrara o Teams e limpara arquivos temporarios." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Confirma? (S/N): " -NoNewline
    $ans = Read-Host
    if ($ans -notmatch "^[sS]") {
        Write-Log -Level "INFO" -Message "Limpeza de cache do Teams cancelada."
        return
    }

    $result = Clear-TeamsCache
    if ($result) {
        Write-Host "Cache do Teams limpo com sucesso." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Teams" -Acao "Limpeza cache" -Resultado "Sucesso"
    } else {
        Write-Host "Nenhum cache foi encontrado para limpar." -ForegroundColor Yellow
        Write-AtlasLog -Nivel WARN -Modulo "Teams" -Acao "Limpeza cache" -Resultado "Falha"
    }
}

function Open-TeamsCacheFolder {
    <#
    .SYNOPSIS
        Abre a pasta de cache do Teams no explorador.
    #>
    [CmdletBinding()]
    param()

    if (-not ($IsWindows -or ($env:OS -like "*Windows*"))) {
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Log -Level "INFO" -Message "Abrindo pasta de cache do Teams..."
    $cacheDir = "$env:AppData\Microsoft\Teams"
    
    if (Test-Path $cacheDir) {
        Write-Host "Abrindo: $cacheDir" -ForegroundColor Cyan
        Invoke-Item $cacheDir
    } else {
        Write-Host "Pasta de cache nao encontrada." -ForegroundColor Yellow
    }
}

function Get-TeamsPersonalStatus {
    <#
    .SYNOPSIS
        Verifica se Teams pessoal/Home esta instalado.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Verificando Teams pessoal..."
    $personalPath = "$env:LocalAppData\Microsoft\Teams\current\Teams.exe"
    $installed = Test-Path $personalPath
    
    Write-Host ""
    Write-Host "Teams Pessoal/Home:" -ForegroundColor Cyan
    if ($installed) {
        Write-Host "  Status: Instalado" -ForegroundColor Green
        Write-Host "  Caminho: $personalPath" -ForegroundColor Gray
    } else {
        Write-Host "  Status: Nao instalado" -ForegroundColor Gray
    }
    
    return $installed
}

function Get-TeamsWorkSchoolStatus {
    <#
    .SYNOPSIS
        Verifica se Teams Work or School (empresarial) esta instalado.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Verificando Teams corporativo..."
    $workPath = "$env:LocalAppData\Packages\MSTeams_8wekyb3d8bbwe"
    $installed = Test-Path $workPath
    
    Write-Host ""
    Write-Host "Teams Work or School:" -ForegroundColor Cyan
    if ($installed) {
        Write-Host "  Status: Instalado (AppX)" -ForegroundColor Green
        Write-Host "  Caminho: $workPath" -ForegroundColor Gray
    } else {
        Write-Host "  Status: Nao instalado" -ForegroundColor Gray
    }

    $corpResult = if ($installed) { "Instalado" } else { "Nao instalado" }
    Write-AtlasLog -Nivel INFO -Modulo "Teams" -Acao "Verificacao Teams corporativo" -Resultado $corpResult
    
    return $installed
}

function Remove-TeamsPersonalSafe {
    <#
    .SYNOPSIS
        Remove Teams pessoal/Home com confirmacao multipla.
    #>
    [CmdletBinding()]
    param()

    if (-not ($IsWindows -or ($env:OS -like "*Windows*"))) {
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    $personalPath = "$env:LocalAppData\Microsoft\Teams"
    
    if (-not (Test-Path $personalPath)) {
        Write-Host "Teams pessoal nao encontrado." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "ATENCAO: Isto encerrara e remocao do Teams Pessoal/Home." -ForegroundColor Red
    Write-Host "Dados de preferencias serao perdidos." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Confirma a remocao? Digite 'SIM' para continuar: " -NoNewline
    $ans = Read-Host
    if ($ans -ne "SIM") {
        Write-Log -Level "INFO" -Message "Remocao do Teams pessoal cancelada."
        return
    }

    Write-Log -Level "WARN" -Message "Removendo Teams pessoal..."
    try {
        Stop-Process -Name "Teams" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Remove-Item -Path "$personalPath\*" -Recurse -Force -ErrorAction Stop
        Write-Host "Teams pessoal foi removido." -ForegroundColor Green
        Write-Log -Level "INFO" -Message "Teams pessoal removido com sucesso."
        Write-AtlasLog -Nivel INFO -Modulo "Teams" -Acao "Remocao Teams pessoal" -Resultado "Sucesso"
    } catch {
        Write-Host "Erro ao remover Teams: $_" -ForegroundColor Red
        Write-Log -Level "ERROR" -Message "Erro ao remover Teams pessoal: $_"
        Write-AtlasLog -Nivel ERROR -Modulo "Teams" -Acao "Remocao Teams pessoal" -Resultado "Falha"
    }
}

function Show-TeamsMenu {
    <#
    .SYNOPSIS
        Exibe o menu do Teams Toolkit.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Menu do Teams aberto."
    $running = $true

    while ($running) {
        Clear-Host
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  Atlas - Microsoft Teams" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "[1] Ver status do Teams"
        Write-Host "[2] Reiniciar Teams"
        Write-Host "[3] Limpar cache do Teams"
        Write-Host "[4] Abrir pasta de cache"
        Write-Host "[5] Detectar Teams Pessoal"
        Write-Host "[6] Detectar Teams Corporativo"
        Write-Host "[7] Remover Teams Pessoal"
        Write-Host "[0] Voltar"
        Write-Host ""

        $option = Read-Host "Escolha uma opcao"

        switch ($option) {
            "1" {
                Write-Host ""
                $status = Get-TeamsStatus
                Write-Host "Status: $(if ($status.ProcessRunning) { "Aberto" } else { "Fechado" })" -ForegroundColor Green
                Write-Log -Level "INFO" -Message "Status do Teams consultado."
                Read-Host "`nPressione Enter para continuar"
            }
            "2" {
                Restart-TeamsSafe
                Read-Host "`nPressione Enter para continuar"
            }
            "3" {
                Clear-TeamsCacheSafe
                Read-Host "`nPressione Enter para continuar"
            }
            "4" {
                Open-TeamsCacheFolder
                Read-Host "`nPressione Enter para continuar"
            }
            "5" {
                Get-TeamsPersonalStatus
                Read-Host "`nPressione Enter para continuar"
            }
            "6" {
                Get-TeamsWorkSchoolStatus
                Read-Host "`nPressione Enter para continuar"
            }
            "7" {
                Remove-TeamsPersonalSafe
                Read-Host "`nPressione Enter para continuar"
            }
            "0" {
                Write-Log -Level "INFO" -Message "Menu do Teams fechado."
                $running = $false
            }
            default {
                Write-Host "Opcao invalida." -ForegroundColor Yellow
                Read-Host "`nPressione Enter para continuar"
            }
        }
    }
}
