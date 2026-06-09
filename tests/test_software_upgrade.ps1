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
    'ConvertFrom-WingetUpgradeJson',
    'Get-WingetUpgradeEntries',
    'Get-WingetAvailableUpgrades',
    'Show-WingetUpgradePreview'
)

foreach ($fn in $removed) {
    Test-Assert (-not (Get-Command $fn -ErrorAction SilentlyContinue)) "Funcao removida: $fn"
}

$source = Get-Content -Path (Join-Path $PSScriptRoot "../modules/software-install.ps1") -Raw

Test-Assert ($source -match 'winget upgrade --all') "Comando winget upgrade --all"
Test-Assert ($source -match '--accept-source-agreements') "Flag --accept-source-agreements"
Test-Assert ($source -match '--accept-package-agreements') "Flag --accept-package-agreements"
Test-Assert ($source -match '--verbose-logs') "Flag --verbose-logs"
Test-Assert ($source -match 'Show-AtlasHeader -Title "Atualizacao de Programas"') "Cabecalho de atualizacao"
Test-Assert ($source -match 'Deseja executar a atualizacao agora') "Confirmacao antes do Winget"
Test-Assert ($source -match 'Resultado "Iniciado"') "Log Iniciado"
Test-Assert ($source -match 'Resultado "Sucesso"') "Log Sucesso"
Test-Assert ($source -match 'Resultado "Falha"') "Log Falha"
Test-Assert ($source -match 'Resultado "Cancelado pelo usuario"') "Log cancelamento"
Test-Assert ($source -notmatch '--output json') "Sem --output json"
Test-Assert ($source -notmatch 'ConvertFrom-WingetUpgradeJson') "Sem parser JSON de upgrades"
Test-Assert ($source -notmatch 'Get-WingetUpgradeEntries') "Sem Get-WingetUpgradeEntries"
Test-Assert ($source -notmatch '\[array\]\$Upgrades') "Sem parametro -Upgrades"
Test-Assert ($source -notmatch 'Nenhuma atualizacao disponivel') "Sem mensagem prematura de lista vazia"
Test-Assert ($source -notmatch 'winget upgrade --all.*Out-Null') "Saida do winget upgrade nao ocultada"
Test-Assert ($source -match 'Show-AtlasHeader -Title "Instalacao de Programas"') "Menu abre diretamente por categorias"
Test-Assert ($source -notmatch 'Show-SoftwareInstallProgramMenu') "Submenu intermediario removido"
Test-Assert ($source -match 'Atualizar programas instalados') "Opcao atualizar no menu"

Write-Host ""
if ($script:UpgradeTestFailed) {
    Write-Host "[FALHA] test_software_upgrade.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_software_upgrade.ps1" -ForegroundColor Green
exit 0
