modules/logger.ps1function Write-Log {

    param(
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $logLine = "[$timestamp] $Message"

    Write-Host $logLine

    Add-Content -Path "./logs/provisionador.log" -Value $logLine
}