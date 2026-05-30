. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/system.ps1"
. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/network.ps1"
. "$PSScriptRoot/../modules/maintenance.ps1"
. "$PSScriptRoot/../modules/disk.ps1"
. "$PSScriptRoot/../modules/process.ps1"
. "$PSScriptRoot/../modules/events.ps1"
. "$PSScriptRoot/../modules/security.ps1"
. "$PSScriptRoot/../modules/report.ps1"

$running = $true
$inputs  = @('1','2','3','4','5','6','7','8','9','10','11','12','13','14','99','0')
$idx     = 0

while ($running) {
    $option = $inputs[$idx]; $idx++
    Write-Host ""
    Write-Host "========================================" -ForegroundColor DarkCyan
    Write-Host "[TESTE] Opcao simulada: $option" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor DarkCyan

    switch ($option) {
        '1'  { Write-Log -Message "Informacoes do sistema" -Level "INFO";              Get-SystemInformation }
        '2'  { Write-Log -Message "Informacoes de rede" -Level "INFO";                 Get-NetworkInformation }
        '3'  { Write-Log -Message "Teste internet e DNS" -Level "INFO";                Test-NetworkConnectivity }
        '4'  { Write-Log -Message "Limpeza temporarios" -Level "INFO";                 Clear-UserTempFiles }
        '5'  { Write-Log -Message "Servicos parados" -Level "INFO";                    Get-StoppedImportantServices }
        '6'  { Write-Log -Message "Uso de disco" -Level "INFO";                        Get-DiskUsage }
        '7'  { Write-Log -Message "Ultimo boot" -Level "INFO";                         Get-LastBootTime }
        '8'  { Write-Log -Message "Top CPU" -Level "INFO";                             Get-TopCpuProcesses }
        '9'  { Write-Log -Message "Top Memoria" -Level "INFO";                         Get-TopMemoryProcesses }
        '10' { Write-Log -Message "Portas comuns" -Level "INFO";                       Test-CommonPorts }
        '11' { Write-Log -Message "Eventos de erro" -Level "INFO";                     Get-RecentErrorEvents }
        '12' { Write-Log -Message "Atualizacoes instaladas" -Level "INFO";             Get-InstalledUpdates }
        '13' { Write-Log -Message "Status Defender" -Level "INFO";                     Get-DefenderStatus }
        '14' { Write-Log -Message "Gerando relatorio" -Level "INFO";                   New-AtlasTxtReport }
        '0'  { Write-Log -Message "Atlas encerrado" -Level "INFO";                     $running = $false }
        default {
            Write-Log -Message "Opcao invalida: $option" -Level "WARN"
            Write-Host "Opcao invalida." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "LOOP ENCERRADO COM SUCESSO" -ForegroundColor Green
