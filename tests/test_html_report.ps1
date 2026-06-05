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

$desktopPath = [Environment]::GetFolderPath("Desktop")
$beforeFiles = @()
if (Test-Path $desktopPath) {
    $beforeFiles = Get-ChildItem -Path $desktopPath -Filter "Atlas_Relatorio_*.html" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
}

Write-Host ""
Write-Host "Gerando relatorio HTML..." -ForegroundColor Gray
$htmlPath = New-AtlasSupportHtmlReport

Write-Host ""
Write-Host "Validando arquivo gerado..." -ForegroundColor Gray

if (-not $htmlPath -or -not (Test-Path $htmlPath)) {
    Write-Host "[FAIL] Arquivo HTML nao foi criado" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Arquivo HTML foi criado" -ForegroundColor Green
Write-Host "     Local: $htmlPath" -ForegroundColor Gray

$allValid = $true

if ($htmlPath -notlike "*.html") {
    Write-Host "[FAIL] Extensao do arquivo nao e .html" -ForegroundColor Red
    $allValid = $false
} else {
    Write-Host "[OK]   Extensao .html" -ForegroundColor Green
}

$fileName = Split-Path $htmlPath -Leaf
if ($fileName -like "Atlas_Relatorio_*") {
    Write-Host "[OK]   Nome Atlas_Relatorio_*" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Nome do arquivo: $fileName" -ForegroundColor Red
    $allValid = $false
}

$desktopNorm = (Resolve-Path $desktopPath).Path
$htmlDirNorm = (Resolve-Path (Split-Path $htmlPath -Parent)).Path
if ($htmlDirNorm -eq $desktopNorm) {
    Write-Host "[OK]   Arquivo na Area de Trabalho" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Arquivo fora da Area de Trabalho: $htmlPath" -ForegroundColor Red
    $allValid = $false
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$reportsRoot = Join-Path $repoRoot "reports"
$afterAtlasDirs = Get-ChildItem -Path $reportsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "atlas_support_*" }
if ($afterAtlasDirs) {
    Write-Host "[INFO] Pastas atlas_support_* existem em reports (relatorio antigo)" -ForegroundColor Gray
} else {
    Write-Host "[OK]   Nenhuma pasta atlas_support_* nova em reports" -ForegroundColor Green
}

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
    @{ Pattern = "Acoes recomendadas"; Name = "Secao Acoes recomendadas" }
)

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
