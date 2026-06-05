# ==========================================
# Atlas - Assistente de Manutencao Windows
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
. "$PSScriptRoot/../modules/outlook.ps1"
. "$PSScriptRoot/../modules/teams.ps1"
. "$PSScriptRoot/../modules/browser.ps1"
. "$PSScriptRoot/../modules/programs.ps1"
. "$PSScriptRoot/../modules/services.ps1"
. "$PSScriptRoot/../modules/software-install.ps1"

# Validacao de import
$requiredFunctions = @(
    "Show-CleanupMenu",
    "Show-NetworkMenu",
    "Show-OneDriveMenu",
    "Show-PrinterMenu",
    "Show-WindowsRepairMenu",
    "Show-OutlookMenu",
    "Show-TeamsMenu",
    "Show-BrowserMenu",
    "Show-SoftwareInstallMenu",
    "Test-WingetAvailable",
    "Install-SoftwareByWingetSafe",
    "Get-SoftwareCatalog",
    "Start-AtlasSessionLog",
    "Stop-AtlasSessionLog"
)

foreach ($fn in $requiredFunctions) {
    if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
        Write-Host "ERRO: Funcao nao carregada: $fn" -ForegroundColor Red
        exit 1
    }
}

$running = $true

try {
    $sessionLog = Start-AtlasSessionLog
    Write-Log -Message "Atlas iniciado" -Level "INFO"
    Write-AtlasSessionLog -Message "Sessao iniciada: $sessionLog" -Level "INFO"

    while ($running) {

        Show-MainMenu
        Write-AtlasSessionLog -Message "Menu principal exibido" -Level "MENU"

        $option = Read-Host "Escolha uma opcao"
        Write-AtlasSessionLog -Message "Menu principal opcao: $option" -Level "MENU"

        switch ($option) {

            "1" {
                Write-AtlasSessionLog -Message "Acao: Limpeza segura" -Level "ACTION"
                Show-CleanupMenu
            }

            "2" {
                Write-AtlasSessionLog -Message "Acao: Rede e internet" -Level "ACTION"
                Show-NetworkMenu
            }

            "3" {
                Write-AtlasSessionLog -Message "Acao: OneDrive" -Level "ACTION"
                Show-OneDriveMenu
            }

            "4" {
                Write-AtlasSessionLog -Message "Acao: Impressoras" -Level "ACTION"
                Show-PrinterMenu
            }

            "5" {
                Write-AtlasSessionLog -Message "Acao: Reparos Windows" -Level "ACTION"
                Show-WindowsRepairMenu
            }

            "6" {
                Write-AtlasSessionLog -Message "Acao: Outlook" -Level "ACTION"
                Show-OutlookMenu
            }

            "7" {
                Write-AtlasSessionLog -Message "Acao: Teams" -Level "ACTION"
                Show-TeamsMenu
            }

            "8" {
                Write-AtlasSessionLog -Message "Acao: Navegadores" -Level "ACTION"
                Show-BrowserMenu
            }

            "9" {
                Write-AtlasSessionLog -Message "Acao: Instalacao de programas" -Level "ACTION"
                Show-SoftwareInstallMenu
            }

            "0" {
                Write-Log -Message "Atlas encerrado pelo usuario" -Level "INFO"
                Write-AtlasSessionLog -Message "Encerrado pelo usuario (opcao 0)" -Level "ACTION"
                $running = $false
            }

            default {
                Write-Log -Message "Opcao invalida selecionada: $option" -Level "WARN"
                Write-AtlasSessionLog -Message "Opcao invalida: $option" -Level "WARN"
                Write-Host "Opcao invalida. Escolha entre 0 e 9." -ForegroundColor Yellow
                Wait-UserInput
            }
        }
    }
}
catch {
    Write-Log -Message "Erro durante execucao do Atlas: $_" -Level "ERROR"
    Write-AtlasSessionLog -Message "Erro fatal: $_" -Level "ERROR"
    Write-Host "Ocorreu um erro. Detalhes no log de sessao." -ForegroundColor Red
}
finally {
    Stop-AtlasSessionLog -Reason "Bootstrap finalizado"
}
