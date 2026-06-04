# ==========================================
# Atlas - Teste Validacao Catalogo Winget
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/software-install.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Validacao catalogo winget" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$required = @(
    'Get-SoftwareCatalog',
    'Test-WingetCatalogItem',
    'Invoke-WingetCatalogValidation',
    'Export-WingetCatalogValidationHtml'
)

foreach ($fn in $required) {
    if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
        Write-Host "[FAIL] Funcao ausente: $fn" -ForegroundColor Red
        exit 1
    }
}

$catalog = Get-SoftwareCatalog
if (-not $catalog) {
    Write-Host "[FAIL] Catalogo nao carregado" -ForegroundColor Red
    exit 1
}

$wingetCheck = Test-WingetAvailable
$canValidate = $wingetCheck.Available

if (-not $canValidate) {
    Write-Host "[AVISO] winget indisponivel neste ambiente." -ForegroundColor Yellow
    Write-Host "        Validacao completa requer Windows com winget." -ForegroundColor Yellow
    Write-Host ""
}

$results = @()
$hasErrors = $false

foreach ($cat in $catalog.categories) {
    foreach ($item in $cat.items) {
        if ($item.id -like "SPECIAL:*") {
            Write-Host "[SKIP] $($item.name) | $($item.id)" -ForegroundColor DarkGray
            continue
        }

        if ($item.manager -ne "winget") {
            continue
        }

        if (-not $canValidate) {
            $results += [PSCustomObject]@{
                Name = $item.name
                Category = $cat.name
                Id = $item.id
                Status = "SKIP"
                Ok = $true
            }
            continue
        }

        Write-Host "Validando: $($item.name) ..." -ForegroundColor Gray
        $test = Test-WingetCatalogItem -PackageId $item.id -DisplayName $item.name
        $results += [PSCustomObject]@{
            Name = $item.name
            Category = $cat.name
            Id = $item.id
            Status = $test.Status
            Ok = $test.Ok
        }

        if ($test.Status -eq "OK") {
            Write-Host "[OK]   $($item.name) | $($item.id)" -ForegroundColor Green
        } elseif ($test.Status -eq "ERRO") {
            Write-Host "[ERRO] $($item.name) | $($item.id)" -ForegroundColor Red
            $hasErrors = $true
        } else {
            Write-Host "[SKIP] $($item.name) | $($item.id)" -ForegroundColor DarkGray
        }
    }
}

$reportPath = Export-WingetCatalogValidationHtml -Results $results
Write-Host ""
Write-Host "Relatorio HTML: $reportPath" -ForegroundColor Cyan

$okCount = @($results | Where-Object { $_.Status -eq "OK" }).Count
$errCount = @($results | Where-Object { $_.Status -eq "ERRO" }).Count
$skipCount = @($results | Where-Object { $_.Status -eq "SKIP" }).Count

Write-Host ""
Write-Host "Resumo: Total=$($results.Count) OK=$okCount ERRO=$errCount SKIP=$skipCount" -ForegroundColor Gray

if (-not $canValidate) {
    Write-Host ""
    Write-Host "[SUCESSO] Catalogo carregado (validacao winget ignorada neste SO)" -ForegroundColor Green
    exit 0
}

if ($hasErrors) {
    Write-Host ""
    Write-Host "[FALHA] Existem pacotes invalidos no catalogo" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[SUCESSO] Catalogo winget validado" -ForegroundColor Green
exit 0
