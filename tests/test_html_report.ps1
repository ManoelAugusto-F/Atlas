# ==========================================
# Atlas - Teste do Relatorio HTML
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/quick-diagnostic.ps1"
. "$PSScriptRoot/../modules/support-report.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Validando geracao de relatorio HTML" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validar funcao existe
Write-Host "Validando existencia da funcao New-AtlasSupportHtmlReport..." -ForegroundColor Gray
if (-not (Get-Command "New-AtlasSupportHtmlReport" -ErrorAction SilentlyContinue)) {
    Write-Host "[FAIL] Funcao New-AtlasSupportHtmlReport nao encontrada" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Funcao encontrada" -ForegroundColor Green

# Executar geracao de relatorio
Write-Host ""
Write-Host "Gerando relatorio HTML..." -ForegroundColor Gray
New-AtlasSupportHtmlReport

# Validar arquivo foi criado
Write-Host ""
Write-Host "Validando arquivo gerado..." -ForegroundColor Gray

$reportsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) "reports"
$latestReport = Get-ChildItem -Path $reportsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "atlas_support_*" } |
    Sort-Object CreationTime -Descending |
    Select-Object -First 1

if (-not $latestReport) {
    Write-Host "[FAIL] Nenhum diretorio de relatorio encontrado" -ForegroundColor Red
    exit 1
}

$htmlFile = Join-Path $latestReport.FullName "report.html"
if (-not (Test-Path $htmlFile)) {
    Write-Host "[FAIL] Arquivo report.html nao foi criado" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Arquivo report.html foi criado" -ForegroundColor Green
Write-Host "     Local: $htmlFile" -ForegroundColor Gray

# Validar conteudo HTML
Write-Host ""
Write-Host "Validando conteudo do HTML..." -ForegroundColor Gray

$htmlContent = Get-Content -Path $htmlFile -Raw

$validations = @(
    @{ Pattern = "<!DOCTYPE html>"; Name = "DOCTYPE HTML" },
    @{ Pattern = "<html"; Name = "Tag HTML" },
    @{ Pattern = "Atlas"; Name = "Titulo Atlas" },
    @{ Pattern = "Relatorio de Suporte"; Name = "Titulo do Relatorio" },
    @{ Pattern = "<style>"; Name = "CSS embutido" },
    @{ Pattern = "section-title"; Name = "Classes CSS" },
    @{ Pattern = "Sistema"; Name = "Secao Sistema" },
    @{ Pattern = "Disco"; Name = "Secao Disco" },
    @{ Pattern = "Rede"; Name = "Secao Rede" }
)

$allValid = $true
foreach ($validation in $validations) {
    if ($htmlContent -match [regex]::Escape($validation.Pattern)) {
        Write-Host "[OK]   $($validation.Name)" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $($validation.Name)" -ForegroundColor Red
        $allValid = $false
    }
}

Write-Host ""
if ($allValid) {
    Write-Host "[SUCESSO] Relatorio HTML validado com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Para visualizar o relatorio, abra:" -ForegroundColor Cyan
    Write-Host "  $htmlFile" -ForegroundColor Yellow
} else {
    Write-Host "[FALHA] Algumas validacoes falharam" -ForegroundColor Red
    exit 1
}

Write-Host ""
