# Browser Toolkit - Modulo Atlas para Automacao de Navegadores
# Totalmente compativel e limpo (ASCII Puro) para rodar em PowerShell 5.1 e 7+

$Global:AtlasLoadedModules = $Global:AtlasLoadedModules | Where-Object { $_ -ne "Browser" }
$Global:AtlasLoadedModules += "Browser"

function Get-BrowserProfiles {
    <#
    .SYNOPSIS
        Detecta e mapeia caminhos e perfis existentes para Chrome, Edge e Firefox do usuario atual.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Mapeando instalacoes de navegadores e perfis..."
    $results = @()

    if ($IsWindows -or ($env:OS -like "*Windows*")) {
        # Google Chrome
        $chromeUserData = "$env:LocalAppData\Google\Chrome\User Data"
        $chromeInstalled = $false
        $chromeProfiles = @()
        if (Test-Path $chromeUserData) {
            $chromeInstalled = $true
            # Filtra subdiretorios de perfil típicos ("Default", "Profile 1", "Profile 2" etc)
            $subFolders = Get-ChildItem -Path $chromeUserData -Directory -ErrorAction SilentlyContinue
            foreach ($folder in $subFolders) {
                if (($folder.Name -eq "Default") -or ($folder.Name -like "Profile *")) {
                    $chromeProfiles += $folder.Name
                }
            }
        }
        $results += [PSCustomObject]@{
            Name        = "Google Chrome"
            Browser     = "Chrome"
            Installed   = $chromeInstalled
            Profiles    = $chromeProfiles
            ProfilePath = if ($chromeInstalled) { $chromeUserData } else { "N/A" }
            CachePath   = if ($chromeInstalled) { $chromeUserData } else { "N/A" }
        }

        # Microsoft Edge
        $edgeUserData = "$env:LocalAppData\Microsoft\Edge\User Data"
        $edgeInstalled = $false
        $edgeProfiles = @()
        if (Test-Path $edgeUserData) {
            $edgeInstalled = $true
            $subFolders = Get-ChildItem -Path $edgeUserData -Directory -ErrorAction SilentlyContinue
            foreach ($folder in $subFolders) {
                if (($folder.Name -eq "Default") -or ($folder.Name -like "Profile *")) {
                    $edgeProfiles += $folder.Name
                }
            }
        }
        $results += [PSCustomObject]@{
            Name        = "Microsoft Edge"
            Browser     = "Edge"
            Installed   = $edgeInstalled
            Profiles    = $edgeProfiles
            ProfilePath = if ($edgeInstalled) { $edgeUserData } else { "N/A" }
            CachePath   = if ($edgeInstalled) { $edgeUserData } else { "N/A" }
        }

        # Mozilla Firefox
        $firefoxProfileDir = "$env:AppData\Mozilla\Firefox\Profiles"
        $firefoxInstalled = $false
        $firefoxProfiles = @()
        if (Test-Path $firefoxProfileDir) {
            $firefoxInstalled = $true
            try {
                $subFolders = Get-ChildItem -Path $firefoxProfileDir -Directory -ErrorAction SilentlyContinue
                foreach ($folder in $subFolders) {
                    $firefoxProfiles += $folder.Name
                }
            } catch {}
        }
        $results += [PSCustomObject]@{
            Name        = "Mozilla Firefox"
            Browser     = "Firefox"
            Installed   = $firefoxInstalled
            Profiles    = $firefoxProfiles
            ProfilePath = if ($firefoxInstalled) { $firefoxProfileDir } else { "N/A" }
            CachePath   = if ($firefoxInstalled) { $firefoxProfileDir } else { "N/A" }
        }
    } else {
        Write-Log -Level "INFO" -Message "Plataforma nao-Windows. Retornando informacoes de teste de navegadores."
        $results += [PSCustomObject]@{
            Name        = "N/A (Nao-Windows)"
            Browser     = "N/A"
            Installed   = $false
            Profiles    = @()
            ProfilePath = "N/A"
            CachePath   = "N/A"
        }
    }

    return $results
}

function Clear-BrowserCache {
    <#
    .SYNOPSIS
        Limpa caches locais e arquivos de dados temporarios de Chrome, Edge e Firefox se fechados.
    .PARAMETER BrowserName
        Nome do navegador para limpar cache ("Chrome", "Edge", "Firefox", "All"). Padre: "All".
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("Chrome", "Edge", "Firefox", "All")]
        [string]$BrowserName = "All"
    )

    Write-Log -Level "INFO" -Message "Comando de limpeza de cache solicitado para: $BrowserName"
    $clearedSomething = $false

    if (!($IsWindows) -and !($env:OS -like "*Windows*")) {
        Write-Log -Level "WARN" -Message "Nao suportado em ambientes que nao sejam Windows."
        return $false
    }

    # Helper para finalizar processos
    $stopProc = {
        param([string]$procName)
        $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Log -Level "WARN" -Message "Processo $procName detectado ativo. Fechando processo..."
            Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    }

    # 1. Google Chrome Cache
    if ($BrowserName -eq "Chrome" -or $BrowserName -eq "All") {
        & $stopProc "chrome"
        $chromeUserData = "$env:LocalAppData\Google\Chrome\User Data"
        if (Test-Path $chromeUserData) {
            Write-Log -Level "INFO" -Message "Limpando diretorios de cache do Google Chrome..."
            # Tenta apagar pastas internas de cache nos sub-perfis
            $profiles = Get-ChildItem -Path $chromeUserData -Directory -ErrorAction SilentlyContinue
            foreach ($p in $profiles) {
                if (($p.Name -eq "Default") -or ($p.Name -like "Profile *")) {
                    # Junta com Join-Path de dois argumentos de forma segura
                    $cacheDir = Join-Path -Path $p.FullName -ChildPath "Cache"
                    if (Test-Path $cacheDir) {
                        try {
                            Remove-Item -Path "$cacheDir\*" -Recurse -Force -ErrorAction SilentlyContinue
                            $clearedSomething = $true
                        } catch {}
                    }
                }
            }
        }
    }

    # 2. Microsoft Edge Cache
    if ($BrowserName -eq "Edge" -or $BrowserName -eq "All") {
        & $stopProc "msedge"
        $edgeUserData = "$env:LocalAppData\Microsoft\Edge\User Data"
        if (Test-Path $edgeUserData) {
            Write-Log -Level "INFO" -Message "Limpando diretorios de cache do Microsoft Edge..."
            $profiles = Get-ChildItem -Path $edgeUserData -Directory -ErrorAction SilentlyContinue
            foreach ($p in $profiles) {
                if (($p.Name -eq "Default") -or ($p.Name -like "Profile *")) {
                    $cacheDir = Join-Path -Path $p.FullName -ChildPath "Cache"
                    if (Test-Path $cacheDir) {
                        try {
                            Remove-Item -Path "$cacheDir\*" -Recurse -Force -ErrorAction SilentlyContinue
                            $clearedSomething = $true
                        } catch {}
                    }
                }
            }
        }
    }

    # 3. Mozilla Firefox Cache
    if ($BrowserName -eq "Firefox" -or $BrowserName -eq "All") {
        & $stopProc "firefox"
        # O cache real do Firefox no Windows fica no Local AppData, e nao no AppData Roaming
        $firefoxCacheRoot = "$env:LocalAppData\Mozilla\Firefox\Profiles"
        if (Test-Path $firefoxCacheRoot) {
            Write-Log -Level "INFO" -Message "Limpando diretorios de cache do Mozilla Firefox..."
            try {
                $profiles = Get-ChildItem -Path $firefoxCacheRoot -Directory -ErrorAction SilentlyContinue
                foreach ($p in $profiles) {
                    $cacheDir = Join-Path -Path $p.FullName -ChildPath "cache2"
                    if (Test-Path $cacheDir) {
                        Remove-Item -Path "$cacheDir\*" -Recurse -Force -ErrorAction SilentlyContinue
                        $clearedSomething = $true
                    }
                }
            } catch {}
        }
    }

    if ($clearedSomething) {
        Write-Log -Level "INFO" -Message "Limpeza de cache dos navegadores concluida com exito."
        return $true
    } else {
        Write-Log -Level "INFO" -Message "Nenhum arquivo de cache de navegador removido."
        return $false
    }
}

function Get-BrowserStatus {
    <#
    .SYNOPSIS
        Retorna o status de navegadores instalados de forma legivel.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Verificando status dos navegadores..."
    Write-Host ""
    
    $profiles = Get-BrowserProfiles
    foreach ($browser in $profiles) {
        $status = if ($browser.Installed) { "Instalado" } else { "Nao instalado" }
        $statusColor = if ($browser.Installed) { "Green" } else { "Gray" }
        Write-Host "$($browser.Name): " -NoNewline
        Write-Host $status -ForegroundColor $statusColor
        if ($browser.Installed -and $browser.Profiles.Count -gt 0) {
            Write-Host "  Perfis: $($browser.Profiles -join ', ')" -ForegroundColor Gray
        }
    }
}

function Open-BrowserProfileFolder {
    <#
    .SYNOPSIS
        Abre a pasta de perfis de um navegador especifico.
    .PARAMETER Browser
        Nome do navegador: "Chrome", "Edge" ou "Firefox".
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("Chrome", "Edge", "Firefox")]
        [string]$Browser = "Chrome"
    )

    if (-not ($IsWindows -or ($env:OS -like "*Windows*"))) {
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Log -Level "INFO" -Message "Abrindo pasta de perfil do $Browser..."

    $paths = @{
        "Chrome" = "$env:LocalAppData\Google\Chrome\User Data"
        "Edge" = "$env:LocalAppData\Microsoft\Edge\User Data"
        "Firefox" = "$env:AppData\Mozilla\Firefox\Profiles"
    }

    $path = $paths[$Browser]
    if (Test-Path $path) {
        Write-Host "Abrindo: $path" -ForegroundColor Cyan
        Invoke-Item $path
    } else {
        Write-Host "Pasta de perfil nao encontrada: $path" -ForegroundColor Yellow
    }
}

function Clear-ChromeCacheSafe {
    <#
    .SYNOPSIS
        Limpa cache do Chrome com confirmacao.
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "Deseja limpar o cache do Google Chrome?" -ForegroundColor Yellow
    Write-Host "Isso encerrara o Chrome temporariamente." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Confirma? (S/N): " -NoNewline
    $ans = Read-Host
    if ($ans -notmatch "^[sS]") {
        Write-Log -Level "INFO" -Message "Limpeza de cache do Chrome cancelada."
        return
    }

    $result = Clear-BrowserCache -BrowserName "Chrome"
    if ($result) {
        Write-Host "Cache do Chrome limpo com sucesso." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Navegadores" -Acao "Chrome" -Resultado "Sucesso"
    } else {
        Write-Host "Nenhum cache foi encontrado para limpar." -ForegroundColor Yellow
        Write-AtlasLog -Nivel WARN -Modulo "Navegadores" -Acao "Chrome" -Resultado "Falha"
    }
}

function Clear-EdgeCacheSafe {
    <#
    .SYNOPSIS
        Limpa cache do Edge com confirmacao.
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "Deseja limpar o cache do Microsoft Edge?" -ForegroundColor Yellow
    Write-Host "Isso encerrara o Edge temporariamente." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Confirma? (S/N): " -NoNewline
    $ans = Read-Host
    if ($ans -notmatch "^[sS]") {
        Write-Log -Level "INFO" -Message "Limpeza de cache do Edge cancelada."
        return
    }

    $result = Clear-BrowserCache -BrowserName "Edge"
    if ($result) {
        Write-Host "Cache do Edge limpo com sucesso." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Navegadores" -Acao "Edge" -Resultado "Sucesso"
    } else {
        Write-Host "Nenhum cache foi encontrado para limpar." -ForegroundColor Yellow
        Write-AtlasLog -Nivel WARN -Modulo "Navegadores" -Acao "Edge" -Resultado "Falha"
    }
}

function Clear-FirefoxCacheSafe {
    <#
    .SYNOPSIS
        Limpa cache do Firefox com confirmacao.
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "Deseja limpar o cache do Mozilla Firefox?" -ForegroundColor Yellow
    Write-Host "Isso encerrara o Firefox temporariamente." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Confirma? (S/N): " -NoNewline
    $ans = Read-Host
    if ($ans -notmatch "^[sS]") {
        Write-Log -Level "INFO" -Message "Limpeza de cache do Firefox cancelada."
        return
    }

    $result = Clear-BrowserCache -BrowserName "Firefox"
    if ($result) {
        Write-Host "Cache do Firefox limpo com sucesso." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Navegadores" -Acao "Firefox" -Resultado "Sucesso"
    } else {
        Write-Host "Nenhum cache foi encontrado para limpar." -ForegroundColor Yellow
        Write-AtlasLog -Nivel WARN -Modulo "Navegadores" -Acao "Firefox" -Resultado "Falha"
    }
}

function Clear-AllBrowserCachesSafe {
    <#
    .SYNOPSIS
        Limpa cache de todos os navegadores com confirmacao.
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "Deseja limpar o cache de TODOS os navegadores?" -ForegroundColor Red
    Write-Host "Isso encerrara Chrome, Edge e Firefox temporariamente." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Confirma? (S/N): " -NoNewline
    $ans = Read-Host
    if ($ans -notmatch "^[sS]") {
        Write-Log -Level "INFO" -Message "Limpeza de cache geral cancelada."
        return
    }

    $result = Clear-BrowserCache -BrowserName "All"
    if ($result) {
        Write-Host "Caches de todos os navegadores foram limpos com sucesso." -ForegroundColor Green
    } else {
        Write-Host "Nenhum cache foi encontrado para limpar." -ForegroundColor Yellow
    }
}

function Show-BrowserMenu {
    <#
    .SYNOPSIS
        Exibe o menu do Browser Toolkit.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Menu de navegadores aberto."
    $running = $true

    while ($running) {
        Show-AtlasHeader -Title "Navegadores"

        Show-AtlasCompactOption -Number "1" -Name "Detectar instalados"
        Show-AtlasCompactOption -Number "2" -Name "Ver perfis"
        Show-AtlasCompactOption -Number "3" -Name "Abrir pasta de perfil"
        Show-AtlasCompactOption -Number "4" -Name "Limpar cache Chrome"
        Show-AtlasCompactOption -Number "5" -Name "Limpar cache Edge"
        Show-AtlasCompactOption -Number "6" -Name "Limpar cache Firefox"
        Show-AtlasCompactOption -Number "7" -Name "Limpar todos os caches"

        Show-AtlasBackOption
        $option = Read-AtlasMenuChoice

        switch ($option) {
            "1" {
                Write-Host ""
                $profiles = Get-BrowserProfiles
                Write-Host "Navegadores instalados:" -ForegroundColor Cyan
                foreach ($p in $profiles) {
                    $status = if ($p.Installed) { "[OK]" } else { "[--]" }
                    Write-Host "$status $($p.Name)" -ForegroundColor Green
                }
                Write-Log -Level "INFO" -Message "Navegadores detectados."
                Wait-UserInput
            }
            "2" {
                Write-Host ""
                Get-BrowserStatus
                Wait-UserInput
            }
            "3" {
                Write-Host ""
                Write-Host "Qual navegador? [1=Chrome, 2=Edge, 3=Firefox]: " -NoNewline -ForegroundColor Magenta
                $browserChoice = Read-Host
                $browserMap = @{"1" = "Chrome"; "2" = "Edge"; "3" = "Firefox"}
                if ($browserChoice -in "1", "2", "3") {
                    Open-BrowserProfileFolder -Browser $browserMap[$browserChoice]
                } else {
                    Write-AtlasWarning "Opcao invalida."
                }
                Wait-UserInput
            }
            "4" {
                Clear-ChromeCacheSafe
                Wait-UserInput
            }
            "5" {
                Clear-EdgeCacheSafe
                Wait-UserInput
            }
            "6" {
                Clear-FirefoxCacheSafe
                Wait-UserInput
            }
            "7" {
                Clear-AllBrowserCachesSafe
                Wait-UserInput
            }
            "0" {
                Write-Log -Level "INFO" -Message "Menu de navegadores fechado."
                $running = $false
            }
            default {
                Write-AtlasWarning "Opcao invalida."
                Wait-UserInput
            }
        }
    }
}
