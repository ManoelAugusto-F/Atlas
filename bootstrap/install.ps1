# ==========================================
# Atlas
# Bootstrap Principal
# ==========================================

# Carregar modulos
. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/system.ps1"
. "$PSScriptRoot/../modules/network.ps1"
. "$PSScriptRoot/../modules/maintenance.ps1"
. "$PSScriptRoot/../modules/disk.ps1"
. "$PSScriptRoot/../modules/triage.ps1"
. "$PSScriptRoot/../modules/corporate-network.ps1"
. "$PSScriptRoot/../modules/windows-health.ps1"
. "$PSScriptRoot/../modules/evidence.ps1"
. "$PSScriptRoot/../modules/inventory.ps1"
. "$PSScriptRoot/../modules/diagnostics.ps1"

Write-Log -Message "Atlas iniciado" -Level "INFO"

# Loop principal
$running = $true

while ($running) {

    Show-MainMenu

    $option = Read-Host "Escolha uma opcao"

    switch ($option) {

        "1" {
            Write-Log -Message "Informacoes do sistema" -Level "INFO"
            Get-SystemInformation
            Wait-UserInput
        }

        "2" {
            Write-Log -Message "Informacoes de rede" -Level "INFO"
            Get-NetworkInformation
            Wait-UserInput
        }

        "3" {
            Write-Log -Message "Teste de internet e DNS" -Level "INFO"
            Test-NetworkConnectivity
            Wait-UserInput
        }

        "4" {
            Write-Log -Message "Limpeza de temporarios do usuario" -Level "INFO"
            Clear-UserTempFiles
            Wait-UserInput
        }

        "5" {
            Write-Log -Message "Listagem de servicos parados importantes" -Level "INFO"
            Get-StoppedImportantServices
            Wait-UserInput
        }

        "6" {
            Write-Log -Message "Uso de disco" -Level "INFO"
            Get-DiskUsage
            Wait-UserInput
        }

        "7" {
            Write-Log -Message "Ultimo boot" -Level "INFO"
            Get-LastBootTime
            Wait-UserInput
        }

        "8" {
            Write-Log -Message "Diagnostico rapido da maquina" -Level "INFO"
            Invoke-QuickMachineTriage
            Wait-UserInput
        }

        "9" {
            Write-Log -Message "Verificacao de saude de rede corporativa" -Level "INFO"
            Test-CorporateNetworkHealth
            Wait-UserInput
        }

        "10" {
            Write-Log -Message "Verificacao de servicos essenciais" -Level "INFO"
            Test-EssentialWindowsServices
            Wait-UserInput
        }

        "11" {
            Write-Log -Message "Verificacao de disco e pastas pesadas" -Level "INFO"
            Get-HeavyUserFolders
            Wait-UserInput
        }

        "12" {
            Write-Log -Message "Verificacao de updates e reboot pendente" -Level "INFO"
            Test-PendingReboot
            Get-WindowsUpdateSummary
            Wait-UserInput
        }

        "13" {
            Write-Log -Message "Verificacao de seguranca basica" -Level "INFO"
            Get-BasicSecurityStatus
            Wait-UserInput
        }

        "14" {
            Write-Log -Message "Coletando evidencias para atendimento" -Level "INFO"
            New-SupportEvidenceBundle
            Wait-UserInput
        }

        "15" {
            Write-Log -Message "Inventario completo" -Level "INFO"
            Invoke-FullInventory
            Wait-UserInput
        }

        "16" {
            Write-Log -Message "Diagnostico corporativo de rede" -Level "INFO"
            Invoke-CorporateDiagnostic
            Wait-UserInput
        }

        "0" {
            Write-Log -Message "Atlas encerrado" -Level "INFO"
            $running = $false
        }

        default {
            Write-Log -Message "Opcao invalida selecionada: $option" -Level "WARN"
            Write-Host "Opcao invalida." -ForegroundColor Yellow
            Wait-UserInput
        }
    }
}