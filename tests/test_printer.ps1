# ==========================================
# Atlas - Teste do Modulo Impressoras
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/printer.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] printer.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script:PrinterTestFailed = $false

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if ($Condition) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:PrinterTestFailed = $true
    }
}

Test-Assert ([bool](Get-Command Get-PrinterList -ErrorAction SilentlyContinue)) "Funcao Get-PrinterList"

$printerSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/printer.ps1") -Raw

if ($printerSource -match '(?s)function Get-PrinterList\s*\{(.+?)\r?\nfunction ') {
    $printerBody = $Matches[1]
    Test-Assert ($printerBody -match '@\(Get-Printer') "Get-PrinterList forca array com @()"
    Test-Assert ($printerBody -match '\$total = \$printers\.Count') "Get-PrinterList calcula total explicitamente"
    Test-Assert ($printerBody -match 'Total: \$total impressora\(s\)') "Get-PrinterList exibe total com numero"
    Test-Assert ($printerBody -match 'Total: 0 impressora\(s\)') "Get-PrinterList exibe zero quando vazio"
    Test-Assert ($printerBody -notmatch 'Total:  impressora\(s\)') "Sem string literal sem numero"
} else {
    Test-Assert $false "Nao foi possivel extrair Get-PrinterList"
}

Write-Host ""
if ($script:PrinterTestFailed) {
    Write-Host "[FALHA] test_printer.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_printer.ps1" -ForegroundColor Green
exit 0
