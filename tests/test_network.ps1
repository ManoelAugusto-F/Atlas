# ==========================================
# Atlas - Teste Rede (v0.5.1)
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/network-tools.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] network-tools.ps1 v0.5.1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script:NetworkTestFailed = $false

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if ($Condition) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:NetworkTestFailed = $true
    }
}

Test-Assert ([bool](Get-Command Get-NetworkConfigBasic -ErrorAction SilentlyContinue)) "Funcao Get-NetworkConfigBasic"
Test-Assert ([bool](Get-Command Get-NetworkConfigFull -ErrorAction SilentlyContinue)) "Funcao Get-NetworkConfigFull"

$networkSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/network-tools.ps1") -Raw

if ($networkSource -match '(?s)function Get-NetworkConfigBasic\s*\{(.+?)\r?\nfunction ') {
    $basicBody = $Matches[1]
    Test-Assert ($basicBody -match 'Configuracao de Rede') "Resumo com titulo Configuracao de Rede"
    Test-Assert ($basicBody -match 'Write-AtlasNetworkSummaryField') "Resumo usa campos formatados"
    Test-Assert ($basicBody -notmatch 'ipconfig /all') "Configuracao padrao sem ipconfig /all"
} else {
    Test-Assert $false "Nao foi possivel extrair Get-NetworkConfigBasic"
}

if ($networkSource -match '(?s)function Get-NetworkConfigFull\s*\{(.+?)\r?\nfunction ') {
    $fullBody = $Matches[1]
    Test-Assert ($fullBody -match 'ipconfig /all') "Detalhes completos usam ipconfig /all"
} else {
    Test-Assert $false "Nao foi possivel extrair Get-NetworkConfigFull"
}

Test-Assert ($networkSource -match 'Ver detalhes completos da rede') "Menu com opcao de detalhes completos"

Write-Host ""
if ($script:NetworkTestFailed) {
    Write-Host "[FALHA] test_network.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_network.ps1" -ForegroundColor Green
exit 0
