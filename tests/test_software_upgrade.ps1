# ==========================================
# Atlas - Teste Atualizacao de Software
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/software-install.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Atualizacao de software" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script:UpgradeTestFailed = $false

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if ($Condition) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:UpgradeTestFailed = $true
    }
}

Test-Assert ([bool](Get-Command Update-InstalledSoftwareSafe -ErrorAction SilentlyContinue)) "Funcao Update-InstalledSoftwareSafe"
Test-Assert ([bool](Get-Command Show-SoftwareInstallMenu -ErrorAction SilentlyContinue)) "Funcao Show-SoftwareInstallMenu"

$removed = @(
    'Get-WingetUpgradeListText',
    'Parse-WingetUpgradeList',
    'Update-WingetPackageVisible',
    'Show-WingetUpgradeSummary',
    'ConvertFrom-WingetUpgradeJson',
    'Get-WingetUpgradeEntries'
)

foreach ($fn in $removed) {
    Test-Assert (-not (Get-Command $fn -ErrorAction SilentlyContinue)) "Funcao removida: $fn"
}

$source = Get-Content -Path (Join-Path $PSScriptRoot "../modules/software-install.ps1") -Raw
$upgradeBlock = (($source -split 'function Update-InstalledSoftwareSafe')[1] -split 'function Export-SoftwareInventory')[0]

Test-Assert ($upgradeBlock -match 'winget upgrade --accept-source-agreements') "Lista via winget upgrade nativo"
Test-Assert ($upgradeBlock -match 'Deseja executar winget upgrade --all agora') "Confirmacao antes do upgrade --all"
Test-Assert ($upgradeBlock -match 'winget upgrade --all --accept-source-agreements --accept-package-agreements') "Upgrade completo nativo"
Test-Assert ($upgradeBlock -match '\[OK\] Atualizacao concluida pelo Winget') "Mensagem de sucesso nativa"
Test-Assert ($upgradeBlock -notmatch 'Parse-WingetUpgradeList') "Sem Parse-WingetUpgradeList"
Test-Assert ($upgradeBlock -notmatch 'Update-WingetPackageVisible') "Sem Update-WingetPackageVisible"
Test-Assert ($upgradeBlock -notmatch 'Show-WingetUpgradeSummary') "Sem resumo customizado"
Test-Assert ($upgradeBlock -notmatch 'Atualizando') "Sem progresso Atualizando N/M"
Test-Assert ($upgradeBlock -notmatch 'winget upgrade --id') "Sem upgrade pacote a pacote"
Test-Assert ($upgradeBlock -notmatch '--output json') "Sem --output json"
Test-Assert ($upgradeBlock -notmatch 'ConvertFrom-Json') "Sem ConvertFrom-Json"
Test-Assert ($upgradeBlock -notmatch '--verbose-logs') "Sem --verbose-logs"
Test-Assert ($upgradeBlock -notmatch 'Out-Null') "Sem Out-Null no fluxo de atualizacao"
Test-Assert ($upgradeBlock -notmatch 'Out-String') "Sem Out-String no fluxo de atualizacao"
Test-Assert ($source -match 'Show-AtlasHeader -Title "Instalacao de Programas"') "Menu abre diretamente por categorias"
Test-Assert ($source -match 'Atualizar programas instalados') "Opcao atualizar no menu"

Write-Host ""
if ($script:UpgradeTestFailed) {
    Write-Host "[FALHA] test_software_upgrade.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_software_upgrade.ps1" -ForegroundColor Green
exit 0
