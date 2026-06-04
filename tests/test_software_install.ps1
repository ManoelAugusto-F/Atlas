# ==========================================
# Atlas - Teste Instalacao de Programas
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/software-install.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] software-install.ps1 v0.2.4" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$functions = @(
    'Show-SoftwareInstallMenu',
    'Test-WingetAvailable',
    'Install-SoftwareByWingetSafe',
    'Get-SoftwareCatalog',
    'Get-SoftwareCategory',
    'Get-SoftwareItem',
    'Show-SoftwareCategoryMenu',
    'Install-RsatFullSafe',
    'Open-Microsoft365InstallPage',
    'Update-InstalledSoftwareSafe',
    'Export-SoftwareInventory',
    'Test-WingetCatalogItem',
    'Invoke-WingetCatalogValidation',
    'Export-WingetCatalogValidationHtml'
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
Write-Host "[TESTE] Get-SoftwareCatalog (somente leitura)" -ForegroundColor Magenta
$catalog = Get-SoftwareCatalog
if (-not $catalog -or -not $catalog.categories) {
    Write-Host "[FAIL] Catalogo nao carregado" -ForegroundColor Red
    exit 1
}

$catCount = @($catalog.categories).Count
$itemCount = 0
foreach ($cat in $catalog.categories) {
    $itemCount += @($cat.items).Count
}
Write-Host "  Categorias: $catCount" -ForegroundColor Gray
Write-Host "  Programas : $itemCount" -ForegroundColor Gray

$expectedCategories = @(
    "Navegadores",
    "PDF e Documentos",
    "Desenvolvimento",
    "Infraestrutura e Redes",
    "Banco de Dados",
    "Microsoft",
    "Utilitarios"
)

foreach ($name in $expectedCategories) {
    $found = Get-SoftwareCategory -CategoryName $name
    if ($found) {
        Write-Host "  [OK] Categoria: $name" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Categoria ausente: $name" -ForegroundColor Red
        $allOk = $false
    }
}

Write-Host ""
if ($allOk) {
    Write-Host "[SUCESSO] test_software_install concluido (sem instalacao real)" -ForegroundColor Green
} else {
    Write-Host "[FALHA] Validacao do catalogo" -ForegroundColor Red
    exit 1
}

Write-Host ""
