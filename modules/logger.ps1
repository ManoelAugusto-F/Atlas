# ==========================================
# Atlas - Modulo de Log
# ==========================================

$script:AtlasSessionLogPath = $null
$script:AtlasSessionActive = $false
$script:AtlasOperationalLogPath = $null
$script:AtlasLoggerInitialized = $false

function script:Test-IsWindowsAtlasLogger {
    return ($IsWindows -or $env:OS -eq 'Windows_NT')
}

function script:Get-AtlasTempPath {
    if ($env:TEMP) { return $env:TEMP }
    if ($env:TMP) { return $env:TMP }
    return [System.IO.Path]::GetTempPath()
}

function script:Get-AtlasDefaultRoot {
    if (script:Test-IsWindowsAtlasLogger) {
        return Join-Path $env:ProgramData "Atlas"
    }
    return Join-Path (script:Get-AtlasTempPath) "Atlas"
}

function Get-AtlasLogPath {
    if ($script:AtlasOperationalLogPath) {
        return $script:AtlasOperationalLogPath
    }

    $logsDir = Join-Path (script:Get-AtlasDefaultRoot) "Logs"
    return Join-Path $logsDir "atlas.log"
}

function Initialize-AtlasLogger {
    param(
        [string]$LogRoot
    )

    $atlasRoot = if ($LogRoot) {
        $LogRoot
    } else {
        script:Get-AtlasDefaultRoot
    }

    $logsDir = Join-Path $atlasRoot "Logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    $script:AtlasOperationalLogPath = Join-Path $logsDir "atlas.log"
    if (-not (Test-Path $script:AtlasOperationalLogPath)) {
        New-Item -ItemType File -Path $script:AtlasOperationalLogPath -Force | Out-Null
    }

    $script:AtlasLoggerInitialized = $true
    return $script:AtlasOperationalLogPath
}

function Write-AtlasLog {
    param(
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Nivel = "INFO",
        [Parameter(Mandatory = $true)]
        [string]$Modulo,
        [Parameter(Mandatory = $true)]
        [string]$Acao,
        [Parameter(Mandatory = $true)]
        [string]$Resultado
    )

    if (-not $script:AtlasLoggerInitialized) {
        Initialize-AtlasLogger | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "$timestamp | $Nivel | $Modulo | $Acao | $Resultado"

    try {
        Add-Content -Path (Get-AtlasLogPath) -Value $logLine -Encoding UTF8
    } catch { }
}

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
