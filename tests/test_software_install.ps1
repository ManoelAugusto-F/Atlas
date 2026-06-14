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
    'Invoke-WingetManaged',
    'Show-AtlasProgressBar',
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
$modulePath = Join-Path $PSScriptRoot "../modules/software-install.ps1"
$moduleText = Get-Content $modulePath -Raw

if ($moduleText -match 'Show-AtlasHeader -Title "Instalacao de Programas"') {
    Write-Host "  [OK] Menu abre diretamente por categorias" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Menu nao exibe categorias diretamente" -ForegroundColor Red
    $allOk = $false
}
if ($moduleText -notmatch 'Show-SoftwareInstallProgramMenu') {
    Write-Host "  [OK] Submenu intermediario removido" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Submenu intermediario ainda presente" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""
Write-Host "[TESTE] Fluxo Install-SoftwareByWingetSafe (analise de arquivo)" -ForegroundColor Magenta

if ($moduleText -notmatch '(?s)function Install-SoftwareByWingetSafe\s*\{(.+?)\r?\nfunction ') {
    Write-Host "  [FAIL] Nao foi possivel extrair Install-SoftwareByWingetSafe" -ForegroundColor Red
    $allOk = $false
} else {
    $installBody = $Matches[1]

    $requiredInstall = @(
        'Invoke-WingetManaged',
        'ATLAS - INSTALACAO',
        'Instalar agora? [S/N]',
        '[OK] Instalacao concluida:',
        '[ERRO] Falha na instalacao:',
        'Codigo de saida:',
        'Log:'
    )

    foreach ($token in $requiredInstall) {
        if ($installBody -match [regex]::Escape($token)) {
            Write-Host "  [OK] Contem: $token" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Ausente: $token" -ForegroundColor Red
            $allOk = $false
        }
    }

    $forbiddenInstall = @(
        '*> $null',
        '$LASTEXITCODE',
        'ConvertFrom-Json',
        '--output json',
        '$env:ComSpec',
        'cmd.exe',
        'Invoke-WingetVisible',
        'Invoke-WingetWithLoading',
        'Parse-WingetUpgradeList',
        'Update-WingetPackageVisible'
    )

    foreach ($token in $forbiddenInstall) {
        if ($installBody -match [regex]::Escape($token)) {
            Write-Host "  [FAIL] Proibido no fluxo de instalacao: $token" -ForegroundColor Red
            $allOk = $false
        } else {
            Write-Host "  [OK] Ausente (correto): $token" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "[TESTE] Invoke-WingetManaged e Show-AtlasProgressBar (analise de arquivo)" -ForegroundColor Magenta

if ($moduleText -notmatch '(?s)function Invoke-WingetManaged\s*\{(.+?)\r?\nfunction ') {
    Write-Host "  [FAIL] Nao foi possivel extrair Invoke-WingetManaged" -ForegroundColor Red
    $allOk = $false
} else {
    $managedBody = $Matches[1]

    $requiredManaged = @(
        'Start-Process',
        'RedirectStandardOutput',
        'RedirectStandardError',
        'ExitCode',
        'Get-WingetLogsDirectory',
        'Show-AtlasProgressBar'
    )

    foreach ($token in $requiredManaged) {
        if ($managedBody -match [regex]::Escape($token)) {
            Write-Host "  [OK] Contem: $token" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Ausente: $token" -ForegroundColor Red
            $allOk = $false
        }
    }
}

if ($moduleText -match 'Atlas\\Logs\\Winget') {
    Write-Host "  [OK] Pasta de logs Winget definida" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Pasta Atlas\Logs\Winget ausente no modulo" -ForegroundColor Red
    $allOk = $false
}

if ($moduleText -notmatch '(?s)function Show-AtlasProgressBar\s*\{') {
    Write-Host "  [FAIL] Show-AtlasProgressBar ausente" -ForegroundColor Red
    $allOk = $false
} else {
    Write-Host "  [OK] Show-AtlasProgressBar definida" -ForegroundColor Green
}

Write-Host ""
if ($allOk) {
    Write-Host "[SUCESSO] test_software_install concluido (sem instalacao real)" -ForegroundColor Green
} else {
    Write-Host "[FALHA] Validacao do modulo de instalacao" -ForegroundColor Red
    exit 1
}

Write-Host ""
