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

Write-Host "Validando existencia da funcao New-AtlasSupportHtmlReport..." -ForegroundColor Gray
if (-not (Get-Command "New-AtlasSupportHtmlReport" -ErrorAction SilentlyContinue)) {
    Write-Host "[FAIL] Funcao New-AtlasSupportHtmlReport nao encontrada" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Funcao encontrada" -ForegroundColor Green

Write-Host ""
Write-Host "Gerando relatorio HTML..." -ForegroundColor Gray
$htmlPath = New-AtlasSupportHtmlReport

Write-Host ""
Write-Host "Validando arquivo gerado..." -ForegroundColor Gray

if (-not $htmlPath -or -not (Test-Path $htmlPath)) {
    $reportsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) "reports"
    $latestReport = Get-ChildItem -Path $reportsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "atlas_support_*" } |
        Sort-Object CreationTime -Descending |
        Select-Object -First 1
    if ($latestReport) {
        $htmlPath = Join-Path $latestReport.FullName "report.html"
    }
}

if (-not $htmlPath -or -not (Test-Path $htmlPath)) {
    Write-Host "[FAIL] Arquivo report.html nao foi criado" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Arquivo report.html foi criado" -ForegroundColor Green
Write-Host "     Local: $htmlPath" -ForegroundColor Gray

Write-Host ""
Write-Host "Validando conteudo do HTML..." -ForegroundColor Gray

$htmlContent = Get-Content -Path $htmlPath -Raw

$validations = @(
    @{ Pattern = "<!DOCTYPE html>"; Name = "DOCTYPE HTML" },
    @{ Pattern = "<html"; Name = "Tag HTML" },
    @{ Pattern = "Atlas"; Name = "Titulo Atlas" },
    @{ Pattern = "Relatorio de Suporte da Maquina"; Name = "Titulo do Relatorio" },
    @{ Pattern = "<style>"; Name = "CSS embutido" },
    @{ Pattern = "Resumo executivo"; Name = "Secao Resumo executivo" },
    @{ Pattern = "Problemas encontrados"; Name = "Secao Problemas encontrados" },
    @{ Pattern = "Diagnostico de lentidao"; Name = "Secao Diagnostico de lentidao" },
    @{ Pattern = "Rede e internet"; Name = "Secao Rede e internet" },
    @{ Pattern = ">RDP<"; Name = "Secao RDP" },
    @{ Pattern = ">OneDrive<"; Name = "Secao OneDrive" },
    @{ Pattern = "Impressoras"; Name = "Secao Impressoras" },
    @{ Pattern = ">Windows<"; Name = "Secao Windows" },
    @{ Pattern = "Acoes recomendadas"; Name = "Secao Acoes recomendadas" },
    @{ Pattern = "card-ok"; Name = "Classe CSS status OK" },
    @{ Pattern = "badge-critico"; Name = "Classe CSS status CRITICO" }
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
    Write-Host "  $htmlPath" -ForegroundColor Yellow
} else {
    Write-Host "[FALHA] Algumas validacoes falharam" -ForegroundColor Red
    exit 1
}

Write-Host ""
