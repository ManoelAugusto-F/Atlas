# ==========================================
# Atlas - Modulo de Log
# ==========================================

$script:AtlasSessionLogPath = $null
$script:AtlasSessionActive = $false
$script:AtlasOperationalLogPath = $null
$script:AtlasLogsDir = $null
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

function script:Ensure-AtlasLogDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $dir = Split-Path $FilePath -Parent
    if ($dir -and -not (Test-Path $dir)) {
        try {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        } catch { }
    }
}

function Get-AtlasLogsRoot {
    if ($script:AtlasLogsDir) {
        return $script:AtlasLogsDir
    }
    return Join-Path (script:Get-AtlasDefaultRoot) "Logs"
}

function Get-AtlasLogPath {
    if ($script:AtlasOperationalLogPath) {
        return $script:AtlasOperationalLogPath
    }
    return Join-Path (Get-AtlasLogsRoot) "atlas.log"
}

function Get-AtlasSessionLogsRoot {
    return Join-Path (Get-AtlasLogsRoot) "Sessions"
}

function Get-AtlasWingetLogsRoot {
    $dir = Join-Path (Get-AtlasLogsRoot) "Winget"
    if (-not (Test-Path $dir)) {
        try {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        } catch { }
    }
    return $dir
}

function Invoke-AtlasLegacyLogCleanup {
    try {
        $logsDir = Get-AtlasLogsRoot
        if (-not $logsDir -or -not (Test-Path $logsDir)) {
            return
        }

        $provisionadorPath = Join-Path $logsDir "provisionador.log"
        if (Test-Path $provisionadorPath) {
            try {
                Remove-Item -Path $provisionadorPath -Force -ErrorAction Stop
            } catch { }
        }

        $wingetDir = Get-AtlasWingetLogsRoot
        $legacyWingetLogs = Get-ChildItem -Path $logsDir -File -Filter 'winget_*.log' -ErrorAction SilentlyContinue

        foreach ($legacyFile in $legacyWingetLogs) {
            try {
                $destination = Join-Path $wingetDir $legacyFile.Name
                if (Test-Path $destination) {
                    Remove-Item -Path $legacyFile.FullName -Force -ErrorAction Stop
                } else {
                    Move-Item -Path $legacyFile.FullName -Destination $destination -Force -ErrorAction Stop
                }
            } catch { }
        }
    } catch { }
}

function Invoke-AtlasLogRetention {
    param(
        [int]$MaxFiles = 30
    )

    $targets = @(
        (Get-AtlasSessionLogsRoot),
        (Get-AtlasWingetLogsRoot)
    )

    foreach ($dir in $targets) {
        if (-not $dir) { continue }

        try {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }

            $files = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending

            if (-not $files) { continue }

            $toRemove = @($files | Select-Object -Skip $MaxFiles)
            foreach ($file in $toRemove) {
                try {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                } catch { }
            }
        } catch { }
    }
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
    $sessionsDir = Join-Path $logsDir "Sessions"
    $wingetDir = Join-Path $logsDir "Winget"

    $script:AtlasLogsDir = $logsDir

    foreach ($dir in @($logsDir, $sessionsDir, $wingetDir)) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            } catch { }
        }
    }

    try {
        Invoke-AtlasLegacyLogCleanup
    } catch { }

    $script:AtlasOperationalLogPath = Join-Path $logsDir "atlas.log"
    if (-not (Test-Path $script:AtlasOperationalLogPath)) {
        try {
            New-Item -ItemType File -Path $script:AtlasOperationalLogPath -Force | Out-Null
        } catch { }
    }

    $script:AtlasLoggerInitialized = $true

    try {
        Invoke-AtlasLogRetention
    } catch { }

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
    $logPath = Get-AtlasLogPath

    try {
        script:Ensure-AtlasLogDirectory -FilePath $logPath
        Add-Content -Path $logPath -Value $logLine -Encoding UTF8
    } catch { }
}

function Get-AtlasSessionLogPath {
    return $script:AtlasSessionLogPath
}

function Start-AtlasSessionLog {
    if (-not $script:AtlasLoggerInitialized) {
        Initialize-AtlasLogger | Out-Null
    }

    $sessionsDir = Get-AtlasSessionLogsRoot

    if (-not (Test-Path $sessionsDir)) {
        try {
            New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null
        } catch { }
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

    try {
        script:Ensure-AtlasLogDirectory -FilePath $script:AtlasSessionLogPath
        Set-Content -Path $script:AtlasSessionLogPath -Value ($header -join "`n") -Encoding UTF8
    } catch { }

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
        script:Ensure-AtlasLogDirectory -FilePath $script:AtlasSessionLogPath
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

    if (-not $script:AtlasLoggerInitialized) {
        Initialize-AtlasLogger | Out-Null
    }

    if ($script:AtlasSessionActive) {
        Write-AtlasSessionLog -Message $Message -Level $Level
    }
}
