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
