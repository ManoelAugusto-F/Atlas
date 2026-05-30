. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/system.ps1"
. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/network.ps1"
. "$PSScriptRoot/../modules/maintenance.ps1"
. "$PSScriptRoot/../modules/disk.ps1"
. "$PSScriptRoot/../modules/triage.ps1"
. "$PSScriptRoot/../modules/corporate-network.ps1"
. "$PSScriptRoot/../modules/windows-health.ps1"
. "$PSScriptRoot/../modules/evidence.ps1"
. "$PSScriptRoot/../modules/inventory.ps1"
. "$PSScriptRoot/../modules/diagnostics.ps1"
. "$PSScriptRoot/../modules/health.ps1"

$running = $true
$inputs  = @('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','99','0')
$idx     = 0

while ($running) {
    $option = $inputs[$idx]; $idx++
    Write-Host ""
    Write-Host "========================================" -ForegroundColor DarkCyan
    Write-Host "[TESTE] Opcao simulada: $option" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor DarkCyan

    switch ($option) {
        '1'  { Write-Log -Message "Informacoes do sistema" -Level "INFO";                  Get-SystemInformation }
        '2'  { Write-Log -Message "Informacoes de rede" -Level "INFO";                     Get-NetworkInformation }
        '3'  { Write-Log -Message "Teste internet e DNS" -Level "INFO";                    Test-NetworkConnectivity }
        '4'  { Write-Log -Message "Limpeza temporarios" -Level "INFO";                     Clear-UserTempFiles }
        '5'  { Write-Log -Message "Servicos parados" -Level "INFO";                        Get-StoppedImportantServices }
        '6'  { Write-Log -Message "Uso de disco" -Level "INFO";                            Get-DiskUsage }
        '7'  { Write-Log -Message "Ultimo boot" -Level "INFO";                             Get-LastBootTime }
        '8'  { Write-Log -Message "Diagnostico rapido" -Level "INFO";                      Invoke-QuickMachineTriage }
        '9'  { Write-Log -Message "Saude de rede corporativa" -Level "INFO";               Test-CorporateNetworkHealth }
        '10' { Write-Log -Message "Servicos essenciais" -Level "INFO";                     Test-EssentialWindowsServices }
        '11' { Write-Log -Message "Pastas pesadas" -Level "INFO";                          Get-HeavyUserFolders }
        '12' { Write-Log -Message "Updates e reboot pendente" -Level "INFO";               Test-PendingReboot; Get-WindowsUpdateSummary }
        '13' { Write-Log -Message "Seguranca basica" -Level "INFO";                        Get-BasicSecurityStatus }
        '14' { Write-Log -Message "Coleta de evidencias" -Level "INFO";                    New-SupportEvidenceBundle }
        '15' { Write-Log -Message "Inventario completo" -Level "INFO";                      Invoke-FullInventory }        '16' { Write-Log -Message "Diagnostico corporativo" -Level "INFO";                   Invoke-CorporateDiagnostic }
        '17' { Write-Log -Message "Saude Windows" -Level "INFO";                            Invoke-WindowsHealthReport }
        '0'  { Write-Log -Message "Atlas encerrado" -Level "INFO";                         $running = $false }
        default {
            Write-Log -Message "Opcao invalida: $option" -Level "WARN"
            Write-Host "Opcao invalida." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "LOOP ENCERRADO COM SUCESSO" -ForegroundColor Green
