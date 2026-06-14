# ==========================================
# Atlas - Teste de Versao
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Versao do Atlas" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script:VersionTestFailed = $false

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if ($Condition) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:VersionTestFailed = $true
    }
}

Test-Assert ([bool](Get-Command Get-AtlasVersion -ErrorAction SilentlyContinue)) "Funcao Get-AtlasVersion"

$version = Get-AtlasVersion
Test-Assert (-not [string]::IsNullOrWhiteSpace($version)) "Versao nao vazia"
Test-Assert ($version -match '^v\d+\.\d+\.\d+$') "Formato vX.Y.Z ($version)"

$versionFile = Join-Path $PSScriptRoot "../version.txt"
Test-Assert (Test-Path $versionFile) "Arquivo version.txt existe"
if (Test-Path $versionFile) {
    $fileVersion = (Get-Content -Path $versionFile -TotalCount 1).Trim()
    Test-Assert ($fileVersion -eq $version) "Get-AtlasVersion coincide com version.txt"
}

$coreSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/core.ps1") -Raw
Test-Assert ($coreSource -match 'Get-AtlasVersion') "core.ps1 define Get-AtlasVersion"
Test-Assert ($coreSource -match 'Atlas \$\(Get-AtlasVersion\)') "Menu principal exibe versao"

Write-Host ""
if ($script:VersionTestFailed) {
    Write-Host "[FALHA] test_version.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_version.ps1" -ForegroundColor Green
exit 0
