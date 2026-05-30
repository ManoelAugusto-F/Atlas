# ==========================================
# Atlas — Assistente de Manutencao Windows
# Bootstrap Principal
# ==========================================

# Carregar modulos essenciais
. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/cleanup.ps1"
. "$PSScriptRoot/../modules/network-tools.ps1"

Write-Log -Message "Atlas iniciado" -Level "INFO"

# Loop principal
$running = $true

while ($running) {

    Show-MainMenu

    $option = Read-Host "Escolha uma opcao"

    switch ($option) {

        "1" {
            Show-FeaturePlaceholder -FeatureName "Diagnostico rapido"
            Wait-UserInput
        }

        "2" {
            Show-CleanupMenu
        }

        "3" {
            Show-NetworkMenu
        }

        "4" {
            Show-FeaturePlaceholder -FeatureName "OneDrive"
            Wait-UserInput
        }

        "5" {
            Show-FeaturePlaceholder -FeatureName "Impressoras"
            Wait-UserInput
        }

        "6" {
            Show-FeaturePlaceholder -FeatureName "Reparos Windows"
            Wait-UserInput
        }

        "7" {
            Show-FeaturePlaceholder -FeatureName "Relatorio de suporte"
            Wait-UserInput
        }

        "0" {
            Write-Log -Message "Atlas encerrado pelo usuario" -Level "INFO"
            $running = $false
        }

        default {
            Write-Log -Message "Opcao invalida selecionada: $option" -Level "WARN"
            Write-Host "Opcao invalida. Escolha entre 0 e 7." -ForegroundColor Yellow
            Wait-UserInput
        }
    }
}