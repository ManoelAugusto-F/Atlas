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
            Browser   = "Google Chrome"
            Installed = $chromeInstalled
            Profiles  = $chromeProfiles
            CachePath = if ($chromeInstalled) { $chromeUserData } else { "N/A" }
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
            Browser   = "Microsoft Edge"
            Installed = $edgeInstalled
            Profiles  = $edgeProfiles
            CachePath = if ($edgeInstalled) { $edgeUserData } else { "N/A" }
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
            Browser   = "Mozilla Firefox"
            Installed = $firefoxInstalled
            Profiles  = $firefoxProfiles
            CachePath = if ($firefoxInstalled) { $firefoxProfileDir } else { "N/A" }
        }
    } else {
        Write-Log -Level "INFO" -Message "Plataforma nao-Windows. Retornando informacoes de teste de navegadores."
        $results += [PSCustomObject]@{
            Browser   = "N/A (Nao-Windows)"
            Installed = $false
            Profiles  = @()
            CachePath = "N/A"
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
