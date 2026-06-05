# ==========================================
# Atlas — Teste de Importacao de Modulos
# ==========================================

# Mock do PSScriptRoot relativo para que o script encontre os modulos
$bootstrapDir = Join-Path $PSScriptRoot "../bootstrap"

# Dot sourcing de todos os arquivos exatamente como no install.ps1
. "$bootstrapDir/../modules/logger.ps1"
. "$bootstrapDir/../modules/core.ps1"
. "$bootstrapDir/../modules/menu.ps1"
. "$bootstrapDir/../modules/quick-diagnostic.ps1"
. "$bootstrapDir/../modules/cleanup.ps1"
. "$bootstrapDir/../modules/network-tools.ps1"
. "$bootstrapDir/../modules/onedrive.ps1"
. "$bootstrapDir/../modules/printer.ps1"
. "$bootstrapDir/../modules/windows-repair.ps1"
. "$bootstrapDir/../modules/outlook.ps1"
. "$bootstrapDir/../modules/teams.ps1"
. "$bootstrapDir/../modules/browser.ps1"
. "$bootstrapDir/../modules/programs.ps1"
. "$bootstrapDir/../modules/services.ps1"
. "$bootstrapDir/../modules/software-install.ps1"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Atlas - Teste de Importacao de Modulos" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Lista de funcoes a validar
$requiredFunctions = @(
    "Invoke-QuickDiagnostic",
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
    "Get-SoftwareCatalog",
    "Start-AtlasSessionLog",
    "Stop-AtlasSessionLog",

    "Test-SfcVerifyOnly",
    "Invoke-SfcScannowSafe",
    "Test-DismCheckHealth",
    "Invoke-DismScanHealthSafe",
    "Invoke-DismRestoreHealthSafe",
    "Reset-WindowsUpdateSafe",

    "Get-OneDriveStatus",
    "Find-OneDriveExecutable",

    "Get-PrinterList",
    "Get-PrintQueueStatus"
)

$allOk = $true

foreach ($fn in $requiredFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] Funcao carregada: $fn" -ForegroundColor Green
    } else {
        Write-Host "  [ERRO] Funcao NAO carregada: $fn" -ForegroundColor Red
        $allOk = $false
    }
}

Write-Host "==========================================" -ForegroundColor Cyan

if (-not $allOk) {
    Write-Host "Falha na validacao de modulos: Algumas funcoes obrigatorias nao foram importadas!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Sucesso: Todas as funcoes e modulos foram importados corretamente!" -ForegroundColor Green
    exit 0
}
