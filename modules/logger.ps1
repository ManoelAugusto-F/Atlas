# ==========================================
# Atlas - Modulo de Log
# ==========================================

$script:AtlasSessionLogPath = $null
$script:AtlasSessionActive = $false

function Get-AtlasLogsRoot {
    return (Join-Path $PSScriptRoot "../logs")
}

function Get-AtlasSessionLogPath {
    return $script:AtlasSessionLogPath
}

function Start-AtlasSessionLog {
    $logsRoot = Get-AtlasLogsRoot
    $sessionsDir = Join-Path $logsRoot "sessions"

    if (-not (Test-Path $sessionsDir)) {
        New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:AtlasSessionLogPath = Join-Path $sessionsDir "session_$timestamp.log"
    $script:AtlasSessionActive = $true

    $osInfo = [System.Environment]::OSVersion.VersionString
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        try {
            $wmiOs = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $osInfo = $wmiOs.Caption
        } catch { }
    }

    $header = @(
        "=========================================="
        "Atlas - Log de Sessao"
        "Inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "Usuario: $([System.Environment]::UserName)"
        "Hostname: $([System.Environment]::MachineName)"
        "PowerShell: $($PSVersionTable.PSVersion)"
        "Sistema: $osInfo"
        "=========================================="
    )

    Set-Content -Path $script:AtlasSessionLogPath -Value ($header -join "`n") -Encoding UTF8
    return $script:AtlasSessionLogPath
}

function Write-AtlasSessionLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "ACTION", "MENU")]
        [string]$Level = "INFO"
    )

    if (-not $script:AtlasSessionActive -or -not $script:AtlasSessionLogPath) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    try {
        Add-Content -Path $script:AtlasSessionLogPath -Value $logLine -Encoding UTF8
    } catch { }
}

function Stop-AtlasSessionLog {
    param(
        [string]$Reason = "Encerramento normal"
    )

    if (-not $script:AtlasSessionActive) {
        return
    }

    Write-AtlasSessionLog -Message "Fim da sessao: $Reason" -Level "INFO"
    Write-AtlasSessionLog -Message "==========================================" -Level "INFO"

    $script:AtlasSessionActive = $false
}

function Write-Log {

    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "WARN"  { Write-Host $logLine -ForegroundColor Yellow }
        "ERROR" { Write-Host $logLine -ForegroundColor Red }
        default { Write-Host $logLine -ForegroundColor Cyan }
    }

    $logDir = Get-AtlasLogsRoot
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $logFile = Join-Path $logDir "provisionador.log"
    Add-Content -Path $logFile -Value $logLine

    if ($script:AtlasSessionActive) {
        Write-AtlasSessionLog -Message $Message -Level $Level
    }
}
