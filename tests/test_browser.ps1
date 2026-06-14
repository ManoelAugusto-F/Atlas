# ==========================================
# Atlas - Teste do Modulo Navegadores
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/browser.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] browser.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script:BrowserTestFailed = $false

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if ($Condition) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:BrowserTestFailed = $true
    }
}

Test-Assert ([bool](Get-Command Get-BrowserProfiles -ErrorAction SilentlyContinue)) "Funcao Get-BrowserProfiles"
Test-Assert ([bool](Get-Command Get-BrowserStatus -ErrorAction SilentlyContinue)) "Funcao Get-BrowserStatus"

$browserSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/browser.ps1") -Raw
Test-Assert ($browserSource -match 'Name\s*=\s*"Google Chrome"') "Chrome com Name legivel"
Test-Assert ($browserSource -match 'Browser\s*=\s*"Chrome"') "Chrome com Browser curto"
Test-Assert ($browserSource -match 'Name\s*=\s*"Microsoft Edge"') "Edge com Name legivel"
Test-Assert ($browserSource -match 'Browser\s*=\s*"Edge"') "Edge com Browser curto"
Test-Assert ($browserSource -match 'Name\s*=\s*"Mozilla Firefox"') "Firefox com Name legivel"
Test-Assert ($browserSource -match 'Browser\s*=\s*"Firefox"') "Firefox com Browser curto"
Test-Assert ($browserSource -notmatch 'Status = "unknown"') "Browser sem status unknown"

$profiles = Get-BrowserProfiles
Test-Assert ($profiles.Count -ge 1) "Get-BrowserProfiles retorna objetos"

foreach ($profile in $profiles) {
    Test-Assert (-not [string]::IsNullOrWhiteSpace($profile.Name)) "Name preenchido para $($profile.Browser)"
    Test-Assert (-not [string]::IsNullOrWhiteSpace($profile.Browser)) "Browser preenchido"
    Test-Assert ($profile.PSObject.Properties.Name -contains 'Installed') "Propriedade Installed presente"
    Test-Assert ($profile.Installed -is [bool]) "Installed e boolean"
}

$expectedNames = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    @('Google Chrome', 'Microsoft Edge', 'Mozilla Firefox')
} else {
    @('N/A (Nao-Windows)')
}

foreach ($expected in $expectedNames) {
    $found = @($profiles | Where-Object { $_.Name -eq $expected }).Count -gt 0
    Test-Assert $found "Nome esperado presente: $expected"
}

Write-Host ""
if ($script:BrowserTestFailed) {
    Write-Host "[FALHA] test_browser.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_browser.ps1" -ForegroundColor Green
exit 0
