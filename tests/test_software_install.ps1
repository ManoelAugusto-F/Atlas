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
if ($installSource -match 'Show-AtlasHeader -Title "Instalacao de Programas"') {
    Write-Host "  [OK] Menu abre diretamente por categorias" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Menu nao exibe categorias diretamente" -ForegroundColor Red
    $allOk = $false
}
if ($installSource -notmatch 'Show-SoftwareInstallProgramMenu') {
    Write-Host "  [OK] Submenu intermediario removido" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Submenu intermediario ainda presente" -ForegroundColor Red
    $allOk = $false
}
if ($installSource -match 'Show-AtlasHeader -Title "Instalacao"') {
    Write-Host "  [OK] Cabecalho visual de instalacao" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Cabecalho visual de instalacao ausente" -ForegroundColor Red
    $allOk = $false
}
$installBlock = (($installSource -split 'function Install-SoftwareByWingetSafe')[1] -split 'function Install-RsatFullSafe')[0]

if ($installBlock -match '\[OK\] Instalacao concluida') {
    Write-Host "  [OK] Resultado amigavel de instalacao" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Resultado amigavel ausente" -ForegroundColor Red
    $allOk = $false
}
if ($installBlock -match 'winget install --id') {
    Write-Host "  [OK] Instalacao usa winget install --id" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Instalacao sem winget install --id" -ForegroundColor Red
    $allOk = $false
}
if ($installBlock -match '--exact') {
    Write-Host "  [OK] Instalacao usa --exact" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Instalacao sem --exact" -ForegroundColor Red
    $allOk = $false
}
if ($installBlock -match '--accept-source-agreements') {
    Write-Host "  [OK] Instalacao usa --accept-source-agreements" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Instalacao sem --accept-source-agreements" -ForegroundColor Red
    $allOk = $false
}
if ($installBlock -match '--accept-package-agreements') {
    Write-Host "  [OK] Instalacao usa --accept-package-agreements" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Instalacao sem --accept-package-agreements" -ForegroundColor Red
    $allOk = $false
}
if ($installBlock -notmatch '--verbose-logs') {
    Write-Host "  [OK] Instalacao sem --verbose-logs" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Instalacao usa --verbose-logs" -ForegroundColor Red
    $allOk = $false
}
if ($installBlock -notmatch '--silent') {
    Write-Host "  [OK] Instalacao sem --silent" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Instalacao usa --silent" -ForegroundColor Red
    $allOk = $false
}
if ($installBlock -notmatch 'winget install.*--disable-interactivity') {
    Write-Host "  [OK] Instalacao sem --disable-interactivity" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Instalacao usa --disable-interactivity" -ForegroundColor Red
    $allOk = $false
}
if ($installBlock -match 'ID Winget:') {
    Write-Host "  [OK] Cabecalho exibe ID Winget" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Cabecalho sem ID Winget" -ForegroundColor Red
    $allOk = $false
}
if ($installBlock -notmatch 'winget install.*Out-Null') {
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
