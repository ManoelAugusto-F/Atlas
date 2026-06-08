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
    'ConvertFrom-WingetUpgradeJson',
    'Get-WingetUpgradeEntries',
    'Get-WingetAvailableUpgrades',
    'Show-WingetUpgradePreview',
    'Update-InstalledSoftwareSafe',
    'Show-SoftwareInstallProgramMenu'
)

foreach ($fn in $required) {
    Test-Assert ([bool](Get-Command $fn -ErrorAction SilentlyContinue)) "Funcao $fn"
}

$sampleJson = @'
{
  "Sources": [
    {
      "Packages": [
        {
          "Name": "Google Chrome",
          "Id": "Google.Chrome",
          "Version": "137.0.7151.56",
          "AvailableVersion": "137.0.7151.69"
        },
        {
          "Name": "Microsoft Edge",
          "Id": "Microsoft.Edge",
          "Version": "137.0.3296.52",
          "AvailableVersion": "137.0.3296.68"
        }
      ]
    }
  ]
}
'@

$parsed = ConvertFrom-WingetUpgradeJson -JsonText $sampleJson
Test-Assert ($parsed.Count -eq 2) "Parser retorna 2 atualizacoes"
Test-Assert ($parsed[0].Name -eq 'Google Chrome') "Primeiro pacote e Google Chrome"
Test-Assert ($parsed[0].Version -eq '137.0.7151.56') "Versao atual parseada"
Test-Assert ($parsed[0].AvailableVersion -eq '137.0.7151.69') "Versao disponivel parseada"

$empty = ConvertFrom-WingetUpgradeJson -JsonText '{"Sources":[{"Packages":[]}]}'
Test-Assert ($empty.Count -eq 0) "Parser trata lista vazia"

$source = Get-Content -Path (Join-Path $PSScriptRoot "../modules/software-install.ps1") -Raw
Test-Assert ($source -match 'Show-WingetUpgradePreview') "Listagem de upgrades implementada"
Test-Assert ($source -match 'Show-AtlasUpgradeSummary') "Resumo final implementado"
Test-Assert ($source -match 'winget upgrade --id') "Atualizacao individual por pacote"
Test-Assert ($source -notmatch 'winget upgrade --all') "Nao usa upgrade --all silencioso"
Test-Assert ($source -match 'Show-SoftwareInstallProgramMenu') "Submenu instalar programa"
Test-Assert ($source -match 'Atualizar programas instalados') "Opcao atualizar no menu"

Write-Host ""
if ($script:UpgradeTestFailed) {
    Write-Host "[FALHA] test_software_upgrade.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_software_upgrade.ps1" -ForegroundColor Green
exit 0
