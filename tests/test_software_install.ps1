# ==========================================
# Atlas - Teste Instalacao de Programas
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/software-install.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] software-install.ps1 MVP" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$functions = @(
    'Show-SoftwareInstallMenu',
    'Show-SoftwareInstallProgramMenu',
    'Test-WingetAvailable',
    'Install-SoftwareByWingetSafe',
    'Get-SoftwareCatalog',
    'Get-SoftwareCategory',
    'Get-SoftwareItem',
    'Show-SoftwareCategoryMenu',
    'Install-RsatFullSafe',
    'Test-Microsoft365WingetAvailable',
    'Test-Microsoft365Installed',
    'Install-Microsoft365AppsSafe',
    'Repair-Microsoft365Safe',
    'Open-Microsoft365InstallPage',
    'Show-Microsoft365Menu',
    'ConvertFrom-WingetUpgradeJson',
    'Get-WingetUpgradeEntries',
    'Get-WingetAvailableUpgrades',
    'Show-WingetUpgradePreview',
    'Update-InstalledSoftwareSafe',
    'Export-SoftwareInventory',
    'Test-WingetCatalogItem',
    'Invoke-WingetCatalogValidation',
    'Export-WingetCatalogValidationHtml',
    'Write-AtlasStep',
    'Write-AtlasResult'
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
Write-Host "[TESTE] Microsoft 365 no catalogo" -ForegroundColor Magenta
$m365 = Get-SoftwareItem -CategoryName "Microsoft" -ItemName "Microsoft 365 Apps"
if ($m365 -and $m365.id -eq "Microsoft.Office") {
    Write-Host "  [OK] Microsoft 365 Apps -> Microsoft.Office (winget)" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Entrada Microsoft 365 Apps invalida" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""
Write-Host "[TESTE] Test-Microsoft365WingetAvailable (sem instalacao)" -ForegroundColor Magenta
$m365Winget = Test-Microsoft365WingetAvailable
if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    Write-Host "  Winget M365 disponivel: $m365Winget" -ForegroundColor Gray
} else {
    Write-Host "  [SKIP] Validacao winget M365 requer Windows" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "[TESTE] Visual de instalacao (software-install.ps1)" -ForegroundColor Magenta
$installSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/software-install.ps1") -Raw
if ($installSource -match 'Show-AtlasHeader -Title "Instalacao"') {
    Write-Host "  [OK] Cabecalho visual de instalacao" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Cabecalho visual de instalacao ausente" -ForegroundColor Red
    $allOk = $false
}
if ($installSource -match 'Write-AtlasResult') {
    Write-Host "  [OK] Resultado amigavel de instalacao" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Resultado amigavel ausente" -ForegroundColor Red
    $allOk = $false
}
if ($installSource -notmatch 'winget install.*Out-Null') {
    Write-Host "  [OK] Saida do winget install nao ocultada" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Saida do winget install ocultada" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""
if ($allOk) {
    Write-Host "[SUCESSO] test_software_install concluido (sem instalacao real)" -ForegroundColor Green
} else {
    Write-Host "[FALHA] Validacao do catalogo" -ForegroundColor Red
    exit 1
}

Write-Host ""
