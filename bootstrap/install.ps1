# ==========================================
# Atlas — Assistente de Manutencao Windows
# Bootstrap Principal
# ==========================================

# Carregar modulos essenciais
. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/quick-diagnostic.ps1"
. "$PSScriptRoot/../modules/cleanup.ps1"
. "$PSScriptRoot/../modules/network-tools.ps1"
. "$PSScriptRoot/../modules/onedrive.ps1"
. "$PSScriptRoot/../modules/printer.ps1"
. "$PSScriptRoot/../modules/windows-repair.ps1"
. "$PSScriptRoot/../modules/support-report.ps1"
. "$PSScriptRoot/../modules/outlook.ps1"
. "$PSScriptRoot/../modules/teams.ps1"
. "$PSScriptRoot/../modules/browser.ps1"
. "$PSScriptRoot/../modules/programs.ps1"
. "$PSScriptRoot/../modules/services.ps1"

# Validacao de import
$requiredFunctions = @(
    "New-AtlasSupportHtmlReport",
    "Show-CleanupMenu",
    "Show-NetworkMenu",
    "Show-OneDriveMenu",
    "Show-PrinterMenu",
    "Show-WindowsRepairMenu",
    "Show-OutlookMenu",
    "Show-TeamsMenu",
    "Show-BrowserMenu"
)

foreach ($fn in $requiredFunctions) {
    if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
        Write-Host "ERRO: Função não carregada: $fn" -ForegroundColor Red
        exit 1
    }
}

Write-Log -Message "Atlas iniciado" -Level "INFO"

# Loop principal
$running = $true

while ($running) {

    Show-MainMenu

    $option = Read-Host "Escolha uma opcao"

    switch ($option) {

        "1" {
            New-AtlasSupportHtmlReport
            Wait-UserInput
        }

        "2" {
            Show-CleanupMenu
        }

        "3" {
            Show-NetworkMenu
        }

        "4" {
            Show-OneDriveMenu
        }

        "5" {
            Show-PrinterMenu
        }

        "6" {
            Show-WindowsRepairMenu
        }

        "7" {
            Show-OutlookMenu
        }

        "8" {
            Show-TeamsMenu
        }

        "9" {
            Show-BrowserMenu
        }

        "0" {
            Write-Log -Message "Atlas encerrado pelo usuario" -Level "INFO"
            $running = $false
        }

        default {
            Write-Log -Message "Opcao invalida selecionada: $option" -Level "WARN"
            Write-Host "Opcao invalida. Escolha entre 0 e 9." -ForegroundColor Yellow
            Wait-UserInput
        }
    }
}