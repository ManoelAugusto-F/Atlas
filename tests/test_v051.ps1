# ==========================================
# Atlas - Teste patch v0.5.1
# ==========================================

$script:PatchTestFailed = $false

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if ($Condition) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:PatchTestFailed = $true
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Patch v0.5.1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$outlookSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/outlook.ps1") -Raw
Test-Assert ($outlookSource -match 'Iniciando diagnostico do Microsoft Outlook') "Outlook com texto correto"
Test-Assert ($outlookSource -notmatch 'Iniciante diagnostico') "Outlook sem typo Iniciante"

$coreSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/core.ps1") -Raw
Test-Assert ($coreSource -match 'function Test-AtlasAdmin') "Test-AtlasAdmin definida"
Test-Assert ($coreSource -match 'Administrador:') "Menu com indicador Administrador"

$menuSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/menu.ps1") -Raw
Test-Assert ($menuSource -match 'Show-AtlasCompactOption -Number "10"') "Menu principal com opcao 10"

Write-Host ""
if ($script:PatchTestFailed) {
    Write-Host "[FALHA] test_v051.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_v051.ps1" -ForegroundColor Green
exit 0
