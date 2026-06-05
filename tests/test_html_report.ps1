# ==========================================
# Atlas - Teste do Relatorio HTML
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/quick-diagnostic.ps1"
. "$PSScriptRoot/../modules/support-report.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Validando relatorio HTML profissional" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command "New-AtlasSupportHtmlReport" -ErrorAction SilentlyContinue)) {
    Write-Host "[FAIL] Funcao New-AtlasSupportHtmlReport nao encontrada" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Funcao encontrada" -ForegroundColor Green

$desktopPath = [Environment]::GetFolderPath("Desktop")

Write-Host ""
Write-Host "Gerando relatorio HTML..." -ForegroundColor Gray
$htmlPath = New-AtlasSupportHtmlReport

if (-not $htmlPath -or -not (Test-Path $htmlPath)) {
    Write-Host "[FAIL] Arquivo HTML nao foi criado" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Arquivo: $htmlPath" -ForegroundColor Green

$allValid = $true
$fileName = Split-Path $htmlPath -Leaf

if ($fileName -like "Atlas_Relatorio_*") {
    Write-Host "[OK]   Nome Atlas_Relatorio_*" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Nome invalido: $fileName" -ForegroundColor Red
    $allValid = $false
}

$desktopNorm = (Resolve-Path $desktopPath).Path
$htmlDirNorm = (Resolve-Path (Split-Path $htmlPath -Parent)).Path
if ($htmlDirNorm -eq $desktopNorm) {
    Write-Host "[OK]   Area de Trabalho" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Fora da Area de Trabalho" -ForegroundColor Red
    $allValid = $false
}

$htmlContent = Get-Content -Path $htmlPath -Raw

$validations = @(
    @{ Pattern = "<!DOCTYPE html>"; Name = "DOCTYPE HTML" },
    @{ Pattern = "<html"; Name = "Tag HTML" },
    @{ Pattern = "Saude Geral da Maquina"; Name = "Score de saude" },
    @{ Pattern = "health-score"; Name = "Score visual" },
    @{ Pattern = "Resumo Executivo"; Name = "Resumo executivo" },
    @{ Pattern = "Problemas Detectados"; Name = "Problemas detectados" },
    @{ Pattern = "Recomendacoes"; Name = "Recomendacoes" },
    @{ Pattern = ">Hardware<"; Name = "Inventario hardware" },
    @{ Pattern = ">Memoria<"; Name = "Analise memoria" },
    @{ Pattern = ">Disco<"; Name = "Analise disco" },
    @{ Pattern = "Maiores pastas do perfil"; Name = "Top pastas perfil" },
    @{ Pattern = "Rede e Internet"; Name = "Rede" },
    @{ Pattern = ">RDP<"; Name = "RDP" },
    @{ Pattern = ">OneDrive<"; Name = "OneDrive" },
    @{ Pattern = "Impressoras"; Name = "Impressoras" },
    @{ Pattern = ">Windows<"; Name = "Windows" },
    @{ Pattern = "Eventos Criticos"; Name = "Eventos criticos" },
    @{ Pattern = "Programas de Inicializacao"; Name = "Programas inicializacao" },
    @{ Pattern = "Windows Defender"; Name = "Windows Defender" },
    @{ Pattern = "Processos Pesados"; Name = "Processos pesados" }
)

Write-Host ""
Write-Host "Validando conteudo..." -ForegroundColor Gray
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
    Write-Host "[SUCESSO] Relatorio HTML profissional validado!" -ForegroundColor Green
    Write-Host "  $htmlPath" -ForegroundColor Yellow
} else {
    Write-Host "[FALHA] Validacoes falharam" -ForegroundColor Red
    exit 1
}

Write-Host ""
