# Outlook Toolkit - Modulo Atlas para Automacao Microsoft Outlook
# Compatibilidade: Windows PowerShell 5.1 e PowerShell 7+
# Codificacao estrita: ASCII puro para evitar quebras de parser

# Garante que dependencias globais existam antes da execucao
$Global:AtlasLoadedModules = $Global:AtlasLoadedModules | Where-Object { $_ -ne "Outlook" }
$Global:AtlasLoadedModules += "Outlook"

function Get-OutlookStatus {
    <#
    .SYNOPSIS
        Verifica a instalacao e o status do Microsoft Outlook local.
    .DESCRIPTION
        Retorna se o Outlook esta instalado no registro, o status do processo
        e os caminhos padrao identificados.
    .OUTPUTS
        PSCustomObject com o status do Outlook.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Iniciante diagnostico do Microsoft Outlook..."

    # Inicializa variaveis padrao
    $installed = $false
    $procRunning = $false
    $outlookVersion = "N/A"
    $executablePath = "N/A"

    # Verifica se o processo esta em execucao
    try {
        $proc = Get-Process -Name "outlook" -ErrorAction SilentlyContinue
        if ($proc) {
            $procRunning = $true
            # Tenta pegar o caminho do executavel no Windows
            if ($IsWindows -or ($env:OS -like "*Windows*")) {
                try { $executablePath = $proc.Path } catch {}
            }
        }
    } catch {
        Write-Log -Level "WARN" -Message "Falha ao ler processos do Outlook."
    }

    # Se for Windows, podemos checar caminhos de registro e arquivos conhecidos
    if ($IsWindows -or ($env:OS -like "*Windows*")) {
        # Procurar caminhos de registro tipicos para o Office
        $regKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE",
            "HKLM:\SOFTWARE\Microsoft\Office\16.0\Outlook",
            "HKLM:\SOFTWARE\Microsoft\Office\15.0\Outlook"
        )
        foreach ($key in $regKeys) {
            if (Test-Path $key) {
                $installed = $true
                try {
                    if ($key -like "*App Paths*") {
                        $outlookPathVal = Get-ItemProperty -Path $key -Name "(Default)" -ErrorAction SilentlyContinue
                        if ($outlookPathVal) { $executablePath = $outlookPathVal."(Default)" }
                    }
                } catch {}
            }
        }

        # Deteccao por caminhos conhecidos de instalacao padrao se nao encontrado pelo registro
        if (!($installed) -and ($executablePath -eq "N/A")) {
            $paths = @(
                "$env:ProgramFiles\Microsoft Office\root\Office16\OUTLOOK.EXE",
                "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\OUTLOOK.EXE",
                "$env:ProgramFiles\Microsoft Office\Office16\OUTLOOK.EXE",
                "$env:ProgramFiles\Microsoft Office\Office15\OUTLOOK.EXE"
            )
            foreach ($p in $paths) {
                if (Test-Path $p) {
                    $installed = $true
                    $executablePath = $p
                    break
                }
            }
        }
    } else {
        # cross-platform mockup
        Write-Log -Level "INFO" -Message "Executando em ambiente nao-Windows. Retornando status simulado."
    }

    $ret = [PSCustomObject]@{
        Installed      = $installed
        ProcessRunning = $procRunning
        ExecutablePath = $executablePath
        OSPlatform     = if ($IsWindows -or ($env:OS -like "*Windows*")) { "Windows" } else { "Non-Windows" }
    }

    Write-Log -Level "INFO" -Message "Status do Outlook mapeado - Instalado: $installed, Em Execucao: $procRunning"

    if ($IsWindows -or ($env:OS -like "*Windows*")) {
        $instLabel = if ($installed) { "Sim" } else { "Nao" }
        $procLabel = if ($procRunning) { "Sim" } else { "Nao" }
        Write-AtlasLog -Nivel INFO -Modulo "Outlook" -Acao "Diagnostico" -Resultado "Instalado: $instLabel | Processo: $procLabel"
        Write-AtlasLog -Nivel INFO -Modulo "Outlook" -Acao "Verificacao instalacao" -Resultado "Instalado: $instLabel"
    }

    return $ret
}

function Restart-OutlookProcess {
    <#
    .SYNOPSIS
        Reinicia o Microsoft Outlook de forma assistida.
    .DESCRIPTION
        Fecha de forma limpa ou forcada o Outlook e inicia uma nova instancia se rodando em Windows.
    .PARAMETER Force
        Se ativo, mata o processo imediatamente sem confirmacao.
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    $status = Get-OutlookStatus
    if (!($status.ProcessRunning)) {
        Write-Log -Level "WARN" -Message "Outlook nao esta em execucao. Nada para reiniciar."
        return $false
    }

    if (!($Force)) {
        Write-Host "Deseja realmente reiniciar o Microsoft Outlook? (S/N): " -NoNewline
        $ans = Read-Host
        if ($ans -notmatch "^[sS]") {
            Write-Log -Level "INFO" -Message "Reinicio do Outlook cancelado pelo usuario."
            return $false
        }
    }

    Write-Log -Level "INFO" -Message "Parando processo do MS Outlook..."
    try {
        Stop-Process -Name "outlook" -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
    } catch {
        Write-Log -Level "ERROR" -Message "Nao foi possivel parar o processo do Outlook: $($_.Exception.Message)"
        return $false
    }

    # Tenta reiniciar se o executavel foi detectado e estamos no Windows
    if (($status.ExecutablePath -and ($status.ExecutablePath -ne "N/A")) -and (Test-Path $status.ExecutablePath)) {
        Write-Log -Level "INFO" -Message "Obtido caminho do Outlook. Reiniciando o processo..."
        try {
            Start-Process -FilePath $status.ExecutablePath
            Write-Log -Level "INFO" -Message "Outlook iniciado com sucesso."
            return $true
        } catch {
            Write-Log -Level "ERROR" -Message "Falha ao iniciar processo Outlook: $($_.Exception.Message)"
        }
    } else {
        Write-Log -Level "WARN" -Message "Caminho do executavel indisponivel para reinicio automatico."
    }

    return $true
}

function Get-OutlookProfiles {
    <#
    .SYNOPSIS
        Procura perfis de email cadastrados do Microsoft Outlook.
    .DESCRIPTION
        Le perfis no Registro do Windows no caminho HKCU\Software\Microsoft\Office\16.0\Outlook\Profiles
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Pesquisando perfis do Outlook..."
    $profiles = @()

    if ($IsWindows -or ($env:OS -like "*Windows*")) {
        $regPaths = @(
            "HKCU:\Software\Microsoft\Office\15.0\Outlook\Profiles",
            "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles",
            "HKCU:\Software\Microsoft\Exchange\Client\Options"
        )
        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                try {
                    $keys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
                    foreach ($k in $keys) {
                        $profiles += $k.PSChildName
                    }
                } catch {
                    Write-Log -Level "WARN" -Message "Erro ao listar subchaves de registro de perfis."
                }
            }
        }
    } else {
        Write-Log -Level "INFO" -Message "Recurso de busca de perfis via registro nao suportado neste SO."
    }

    if ($profiles.Count -eq 0) {
        Write-Log -Level "INFO" -Message "Nenhum perfil de Outlook encontrado."
    } else {
        Write-Log -Level "INFO" -Message "Perfeis encontrados: $($profiles -join ', ')"
    }

    return $profiles
}

function Restart-OutlookSafe {
    <#
    .SYNOPSIS
        Reinicia o Outlook com confirmacao do usuario.
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "Confirma o reinicio do Microsoft Outlook? (S/N): " -NoNewline
    $ans = Read-Host
    if ($ans -notmatch "^[sS]") {
        Write-Log -Level "INFO" -Message "Reinicio do Outlook cancelado."
        return
    }

    Restart-OutlookProcess -Force
    Write-Host "Outlook foi reiniciado." -ForegroundColor Green
    Write-Log -Level "INFO" -Message "Outlook reiniciado com sucesso."
}

function Open-OutlookDataFolder {
    <#
    .SYNOPSIS
        Abre a pasta de dados do Outlook (PST/OST).
    #>
    [CmdletBinding()]
    param()

    if (-not ($IsWindows -or ($env:OS -like "*Windows*"))) {
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Log -Level "INFO" -Message "Abrindo pasta de dados do Outlook..."
    $dataPath = "$env:LocalAppData\Microsoft\Outlook"
    
    if (Test-Path $dataPath) {
        Write-Host "Abrindo: $dataPath" -ForegroundColor Cyan
        Invoke-Item $dataPath
        Write-Log -Level "INFO" -Message "Pasta de dados aberta: $dataPath"
    } else {
        Write-Host "Pasta de dados nao encontrada: $dataPath" -ForegroundColor Yellow
        Write-Log -Level "WARN" -Message "Pasta de dados do Outlook nao existe."
    }
}

function Open-OutlookCacheFolder {
    <#
    .SYNOPSIS
        Abre a pasta RoamCache do Outlook.
    #>
    [CmdletBinding()]
    param()

    if (-not ($IsWindows -or ($env:OS -like "*Windows*"))) {
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Log -Level "INFO" -Message "Abrindo pasta RoamCache do Outlook..."
    $cachePath = "$env:LocalAppData\Microsoft\Outlook\RoamCache"
    
    if (Test-Path $cachePath) {
        Write-Host "Abrindo: $cachePath" -ForegroundColor Cyan
        Invoke-Item $cachePath
        Write-Log -Level "INFO" -Message "Pasta RoamCache aberta."
    } else {
        Write-Host "Pasta RoamCache nao encontrada. Pode ser criada na proxima sincronizacao." -ForegroundColor Yellow
    }
}

function Clear-OutlookRoamCacheSafe {
    <#
    .SYNOPSIS
        Limpa o cache RoamCache do Outlook com confirmacao.
    #>
    [CmdletBinding()]
    param()

    if (-not ($IsWindows -or ($env:OS -like "*Windows*"))) {
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    $cachePath = "$env:LocalAppData\Microsoft\Outlook\RoamCache"
    
    if (-not (Test-Path $cachePath)) {
        Write-Host "Pasta RoamCache nao encontrada. Nada para limpar." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Deseja limpar o cache RoamCache do Outlook?" -ForegroundColor Yellow
    Write-Host "Isso forcara o Outlook a resincronizar dados na proxima execucao." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Confirma? (S/N): " -NoNewline
    $ans = Read-Host
    if ($ans -notmatch "^[sS]") {
        Write-Log -Level "INFO" -Message "Limpeza de RoamCache cancelada."
        return
    }

    $status = Get-OutlookStatus
    if ($status.ProcessRunning) {
        Write-Host ""
        Write-Host "Aviso: Outlook esta em execucao. Encerrando..." -ForegroundColor Yellow
        try {
            Stop-Process -Name "outlook" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        } catch {}
    }

    Write-Log -Level "INFO" -Message "Removendo cache RoamCache: $cachePath"
    try {
        Remove-Item -Path "$cachePath\*" -Recurse -Force -ErrorAction Stop
        Write-Host "Cache RoamCache limpo com sucesso." -ForegroundColor Green
        Write-Log -Level "INFO" -Message "Cache RoamCache limpo."
    } catch {
        Write-Host "Erro ao limpar cache: $_" -ForegroundColor Red
        Write-Log -Level "ERROR" -Message "Erro ao limpar RoamCache: $_"
    }
}

function Open-OfficeRepairPanel {
    if (-not ($IsWindows -or ($env:OS -like "*Windows*"))) {
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Log -Level "INFO" -Message "Abrindo painel de reparo do Office..."
    Write-Host ""
    Write-Host "Orientacao:" -ForegroundColor Cyan
    Write-Host "  Procure Microsoft Office ou Microsoft 365, clique em Alterar/Reparar." -ForegroundColor Gray
    Write-Host ""

    try {
        Start-Process "appwiz.cpl"
        Write-Host "Painel Programas e Recursos aberto." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Outlook" -Acao "Reparo Office" -Resultado "Sucesso"
    } catch {
        try {
            Start-Process "ms-settings:appsfeatures"
            Write-Host "Configuracoes de aplicativos abertas." -ForegroundColor Green
            Write-AtlasLog -Nivel INFO -Modulo "Outlook" -Acao "Reparo Office" -Resultado "Sucesso"
        } catch {
            Write-Host "Erro ao abrir painel: $_" -ForegroundColor Red
            Write-Log -Level "ERROR" -Message "Erro ao abrir reparo Office: $_"
            Write-AtlasLog -Nivel ERROR -Modulo "Outlook" -Acao "Reparo Office" -Resultado "Falha"
        }
    }
}

function Open-InstalledAppsForOffice {
    if (-not ($IsWindows -or ($env:OS -like "*Windows*"))) {
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Log -Level "INFO" -Message "Abrindo Apps instalados para Office/Outlook..."
    Write-Host ""
    Write-Host "Orientacao:" -ForegroundColor Cyan
    Write-Host "  Busque Microsoft Office, Microsoft 365 ou Outlook para desinstalar ou modificar." -ForegroundColor Gray
    Write-Host "  NAO removemos PST/OST automaticamente." -ForegroundColor Yellow
    Write-Host ""

    try {
        Start-Process "ms-settings:appsfeatures"
        Write-Host "Apps instalados aberto." -ForegroundColor Green
    } catch {
        Write-Host "Erro ao abrir configuracoes: $_" -ForegroundColor Red
        Write-Log -Level "ERROR" -Message "Erro ao abrir appsfeatures: $_"
    }
}

function Open-OfficeDownloadPage {
    Write-Log -Level "INFO" -Message "Abrindo pagina oficial Microsoft 365/Office..."
    $url = "https://www.microsoft.com/pt-br/microsoft-365"
    try {
        Start-Process $url
        Write-Host ""
        Write-Host "Pagina oficial aberta. Faca download manual se necessario." -ForegroundColor Green
    } catch {
        Write-Host "Erro ao abrir navegador: $_" -ForegroundColor Red
        Write-Log -Level "ERROR" -Message "Erro ao abrir pagina Office: $_"
    }
}

function Show-OutlookMenu {
    <#
    .SYNOPSIS
        Exibe o menu do Outlook Toolkit.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Menu do Outlook aberto."
    $running = $true

    while ($running) {
        Show-AtlasMenuHeader -Title "Outlook"

        Show-AtlasMenuOption -Number "1" -Name "Ver status do Outlook" `
            -Description "Mostra se o Outlook esta aberto e instalado" -Risk "nenhum"
        Show-AtlasMenuOption -Number "2" -Name "Reiniciar Outlook" `
            -Description "Fecha e abre o Outlook novamente" -Risk "baixo"
        Show-AtlasMenuOption -Number "3" -Name "Abrir pasta de dados" `
            -Description "Acessa arquivos de e-mail e perfis" -Risk "nenhum"
        Show-AtlasMenuOption -Number "4" -Name "Abrir pasta RoamCache" `
            -Description "Acessa cache de configuracoes do Outlook" -Risk "nenhum"
        Show-AtlasMenuOption -Number "5" -Name "Limpar cache RoamCache" `
            -Description "Remove cache que pode causar erros" -Risk "baixo"
        Show-AtlasMenuOption -Number "6" -Name "Ver perfis do Outlook" `
            -Description "Lista contas configuradas no Outlook" -Risk "nenhum"
        Show-AtlasMenuOption -Number "7" -Name "Reparar Office/Outlook" `
            -Description "Abre ferramenta oficial de reparo da Microsoft" -Risk "baixo"
        Show-AtlasMenuOption -Number "8" -Name "Apps instalados (Office)" `
            -Description "Abre configuracoes para desinstalar Office" -Risk "medio"
        Show-AtlasMenuOption -Number "9" -Name "Pagina oficial Microsoft 365" `
            -Description "Abre site para download ou suporte" -Risk "nenhum"

        Show-AtlasMenuBackOption
        $option = Read-AtlasMenuChoice

        switch ($option) {
            "1" {
                Write-Host ""
                $status = Get-OutlookStatus
                Write-AtlasSuccess "Status: $(if ($status.ProcessRunning) { "Aberto" } else { "Fechado" })"
                Write-AtlasInfo "Instalado: $(if ($status.Installed) { "Sim" } else { "Nao" })"
                Write-Log -Level "INFO" -Message "Status do Outlook consultado."
                Wait-UserInput
            }
            "2" {
                Restart-OutlookSafe
                Wait-UserInput
            }
            "3" {
                Open-OutlookDataFolder
                Wait-UserInput
            }
            "4" {
                Open-OutlookCacheFolder
                Wait-UserInput
            }
            "5" {
                Clear-OutlookRoamCacheSafe
                Wait-UserInput
            }
            "6" {
                Write-Host ""
                $profiles = Get-OutlookProfiles
                if ($profiles.Count -eq 0) {
                    Write-AtlasWarning "Nenhum perfil encontrado."
                } else {
                    Write-AtlasSuccess "Perfis encontrados:"
                    $profiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
                }
                Write-Log -Level "INFO" -Message "Perfis do Outlook consultados."
                Wait-UserInput
            }
            "7" {
                Open-OfficeRepairPanel
                Wait-UserInput
            }
            "8" {
                Open-InstalledAppsForOffice
                Wait-UserInput
            }
            "9" {
                Open-OfficeDownloadPage
                Wait-UserInput
            }
            "0" {
                Write-Log -Level "INFO" -Message "Menu do Outlook fechado."
                $running = $false
            }
            default {
                Write-AtlasWarning "Opcao invalida."
                Wait-UserInput
            }
        }
    }
}
