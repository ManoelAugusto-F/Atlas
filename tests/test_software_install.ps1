# ==========================================
# Atlas - Teste Instalacao de Programas
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/software-install.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] software-install.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$functions = @(
    'Show-SoftwareInstallMenu',
    'Test-WingetAvailable',
    'Install-SoftwareByWingetSafe',
    'Show-BrowserInstallMenu',
    'Show-DevInstallMenu',
    'Show-PdfInstallMenu',
    'Show-UtilitiesInstallMenu',
    'Install-RecommendedPackageSafe'
)

$allOk = $true
foreach ($fn in $functions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "[OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $fn" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    exit 1
}

Write-Host ""
Write-Host "[TESTE] Test-WingetAvailable (somente leitura)" -ForegroundColor Magenta
$result = Test-WingetAvailable
Write-Host "  Disponivel: $($result.Available)" -ForegroundColor Gray
Write-Host "  Mensagem  : $($result.Message)" -ForegroundColor Gray

Write-Host ""
Write-Host "[SUCESSO] test_software_install concluido (sem instalacao real)" -ForegroundColor Green
Write-Host ""
