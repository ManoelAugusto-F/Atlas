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

$required = @(
    'Get-WingetUpgradeListText',
    'Parse-WingetUpgradeList',
    'Update-WingetPackageVisible',
    'Show-WingetUpgradeSummary',
    'Update-InstalledSoftwareSafe',
    'Show-SoftwareInstallMenu'
)

foreach ($fn in $required) {
    Test-Assert ([bool](Get-Command $fn -ErrorAction SilentlyContinue)) "Funcao $fn"
}

$sampleList = @'
Nome                   ID                               Versão               Disponível           Origem
--------------------------------------------------------------------------------------------------------
Notepad++ (64-bit x64) Notepad++.Notepad++              8.9.6                8.9.6.4              winget
Google Chrome          Google.Chrome                    149.0.7827.102       149.0.7827.103       winget
7 atualizações disponíveis.
Nome  ID          Versão   Disponível Origem
--------------------------------------------
MSYS2 MSYS2.MSYS2 20251213 20260322   winget
'@

$parsed = @(Parse-WingetUpgradeList -Text $sampleList)
Test-Assert ($parsed.Count -ge 3) "Parser extrai pacotes da saida textual"
Test-Assert ($parsed[0].Id -eq 'Notepad++.Notepad++') "Parser extrai ID Winget"
Test-Assert ($parsed[0].Name -match 'Notepad') "Parser extrai nome do programa"
Test-Assert ($parsed[0].Version -eq '8.9.6') "Parser extrai versao atual"
Test-Assert ($parsed[0].AvailableVersion -eq '8.9.6.4') "Parser extrai versao disponivel"

$source = Get-Content -Path (Join-Path $PSScriptRoot "../modules/software-install.ps1") -Raw

Test-Assert ($source -match 'winget upgrade --accept-source-agreements') "Lista inicial via winget upgrade"
Test-Assert ($source -match 'Deseja atualizar todos os programas listados') "Confirmacao apos listagem"
Test-Assert ($source -match 'Atualizando \$Index/\$Total') "Progresso Atualizando N/M"
Test-Assert ($source -match 'winget upgrade --id') "Atualizacao individual por ID"
Test-Assert ($source -match 'winget upgrade --all') "Fallback winget upgrade --all"
Test-Assert ($source -match '--exact') "Flag --exact"
Test-Assert ($source -match '--accept-source-agreements') "Flag --accept-source-agreements"
Test-Assert ($source -match '--accept-package-agreements') "Flag --accept-package-agreements"
Test-Assert ($source -match '--verbose-logs') "Flag --verbose-logs"
Test-Assert ($source -match 'Show-WingetUpgradeSummary') "Resumo final implementado"
Test-Assert ($source -notmatch '--output json') "Sem --output json"
$upgradeBlock = (($source -split 'function Update-InstalledSoftwareSafe')[1] -split 'function Export-SoftwareInventory')[0]
Test-Assert ($upgradeBlock -notmatch 'ConvertFrom-Json') "Sem ConvertFrom-Json no fluxo de atualizacao"
Test-Assert ($source -notmatch 'winget upgrade --id.*Out-Null') "Saida do upgrade por pacote nao ocultada"
Test-Assert ($source -notmatch 'winget upgrade --all.*Out-Null') "Saida do fallback --all nao ocultada"
Test-Assert ($source -match 'Show-AtlasHeader -Title "Instalacao de Programas"') "Menu abre diretamente por categorias"
Test-Assert ($source -match 'Atualizar programas instalados') "Opcao atualizar no menu"

Write-Host ""
if ($script:UpgradeTestFailed) {
    Write-Host "[FALHA] test_software_upgrade.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_software_upgrade.ps1" -ForegroundColor Green
exit 0
