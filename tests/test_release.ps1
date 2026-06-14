# ==========================================
# Atlas - Teste de Bootstrap por Release
# ==========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Bootstrap por Release" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script:ReleaseTestFailed = $false

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if ($Condition) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:ReleaseTestFailed = $true
    }
}

$bootstrapPaths = @(
    (Join-Path $PSScriptRoot "../i.ps1"),
    (Join-Path $PSScriptRoot "../online/install.ps1")
)

foreach ($path in $bootstrapPaths) {
    $name = Split-Path $path -Leaf
    $dir = Split-Path $path -Parent | Split-Path -Leaf
    $label = if ($dir -eq 'online') { "online/$name" } else { $name }

    if (-not (Test-Path $path)) {
        Test-Assert $false "Arquivo $label existe"
        continue
    }

    $source = Get-Content -Path $path -Raw
    Test-Assert ($source -match 'function Get-LatestAtlasRelease') "$label contem Get-LatestAtlasRelease"
    Test-Assert ($source -match 'function Download-AtlasRelease') "$label contem Download-AtlasRelease"
    Test-Assert ($source -match 'AtlasReleasesApiUrl') "$label define URL da API de releases"
    Test-Assert ($source -match 'releases/latest') "$label consulta endpoint releases/latest"
    Test-Assert ($source -match 'zipball_url') "$label suporta zipball_url"
    Test-Assert ($source -match 'Versao encontrada:') "$label exibe versao encontrada"
    Test-Assert ($source -match 'Nao foi possivel consultar releases') "$label possui fallback"
    Test-Assert ($source -match 'Tentando metodo alternativo') "$label mensagem de fallback"
    Test-Assert ($source -match 'AtlasFallbackZipUrl') "$label URL fallback configuravel"
    Test-Assert ($source -match 'try\s*\{') "$label possui tratamento try/catch"
    Test-Assert ($source -match 'return \$null') "$label retorna null em falha de API"
    Test-Assert ($source -match 'Version\s*=\s*\$response\.tag_name') "$label retorna Version da release"
    Test-Assert ($source -match 'DownloadUrl\s*=') "$label retorna DownloadUrl"
}

$iSource = Get-Content -Path (Join-Path $PSScriptRoot "../i.ps1") -Raw
$onlineSource = Get-Content -Path (Join-Path $PSScriptRoot "../online/install.ps1") -Raw
Test-Assert ($iSource -eq $onlineSource) "i.ps1 e online/install.ps1 identicos"

Write-Host ""
if ($script:ReleaseTestFailed) {
    Write-Host "[FALHA] test_release.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_release.ps1" -ForegroundColor Green
exit 0
