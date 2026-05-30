. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/system.ps1"
. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/network.ps1"
. "$PSScriptRoot/../modules/maintenance.ps1"
. "$PSScriptRoot/../modules/disk.ps1"

$running = $true
$inputs = @('1', '2', '3', '4', '5', '6', '7', '9', '0')
$idx = 0

while ($running) {
    $option = $inputs[$idx]; $idx++
    Write-Host ""
    Write-Host "========================================" -ForegroundColor DarkCyan
    Write-Host "[TESTE] Opcao simulada: $option" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor DarkCyan

    switch ($option) {
        '1' { Write-Log -Message "Informacoes do sistema" -Level "INFO"; Get-SystemInformation }
        '2' { Write-Log -Message "Informacoes de rede" -Level "INFO"; Get-NetworkInformation }
        '3' { Write-Log -Message "Teste de internet e DNS" -Level "INFO"; Test-NetworkConnectivity }
        '4' { Write-Log -Message "Limpeza de temporarios" -Level "INFO"; Clear-UserTempFiles }
        '5' { Write-Log -Message "Servicos parados" -Level "INFO"; Get-StoppedImportantServices }
        '6' { Write-Log -Message "Uso de disco" -Level "INFO"; Get-DiskUsage }
        '7' { Write-Log -Message "Ultimo boot" -Level "INFO"; Get-LastBootTime }
        '0' { Write-Log -Message "Atlas encerrado" -Level "INFO"; $running = $false }
        default {
            Write-Log -Message "Opcao invalida: $option" -Level "WARN"
            Write-Host "Opcao invalida." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "LOOP ENCERRADO COM SUCESSO" -ForegroundColor Green
