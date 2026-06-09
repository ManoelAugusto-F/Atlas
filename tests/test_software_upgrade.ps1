# ==========================================
# Atlas - Teste Atualizacao de Programas
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/software-install.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] software-upgrade.ps1 MVP" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$functions = @(
    'Get-WingetAvailableUpgrades',
    'Update-InstalledSoftwareSafe'
)

$allOk = $true
foreach ($fn in $functions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "[OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $fn" -ForegroundColor Red
        $allOk = $false
    }
}

$removed = @(
    'Invoke-WingetWithLoading',
    'Invoke-WingetVisible',
    'Get-WingetUpgradeListText',
    'Parse-WingetUpgradeList',
    'Update-WingetPackageVisible',
    'Show-WingetUpgradeSummary',
    'ConvertFrom-WingetUpgradeJson',
    'Get-WingetUpgradeEntries'
)

foreach ($fn in $removed) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "[FAIL] Funcao removida ainda presente: $fn" -ForegroundColor Red
        $allOk = $false
    } else {
        Write-Host "[OK] Funcao removida ausente: $fn" -ForegroundColor Green
    }
}

$modulePath = Join-Path $PSScriptRoot "../modules/software-install.ps1"
$moduleText = Get-Content $modulePath -Raw

Write-Host ""
Write-Host "[TESTE] Fluxo Update-InstalledSoftwareSafe (analise de arquivo)" -ForegroundColor Magenta

if ($moduleText -notmatch '(?s)function Update-InstalledSoftwareSafe\s*\{(.+?)\r?\nfunction ') {
    Write-Host "  [FAIL] Nao foi possivel extrair Update-InstalledSoftwareSafe" -ForegroundColor Red
    $allOk = $false
} else {
    $upgradeBody = $Matches[1]

    $requiredUpgrade = @(
        'winget upgrade --all',
        '--accept-source-agreements',
        '--accept-package-agreements',
        '*> $null',
        '$LASTEXITCODE',
        'Esta opcao executa a atualizacao de programas via Winget.',
        'Executar atualizacao agora? [S/N]',
        'Atualizando programas. Aguarde...',
        '[OK] Atualizacao concluida.',
        '[ERRO] Nao foi possivel concluir a atualizacao.',
        'Codigo de saida:',
        'Tente executar manualmente:'
    )

    foreach ($token in $requiredUpgrade) {
        if ($upgradeBody -match [regex]::Escape($token)) {
            Write-Host "  [OK] Contem: $token" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Ausente: $token" -ForegroundColor Red
            $allOk = $false
        }
    }

    $forbiddenUpgrade = @(
        'Invoke-WingetWithLoading',
        'Invoke-WingetVisible',
        'Start-Process',
        '$env:ComSpec',
        'RedirectStandardOutput',
        'RedirectStandardError',
        'winget_',
        'Executando Winget',
        '--output json',
        'ConvertFrom-Json',
        'Parse-WingetUpgradeList',
        'Update-WingetPackageVisible',
        'Show-WingetUpgradeSummary',
        '-Upgrades',
        'Get-WingetAvailableUpgrades',
        'winget upgrade --id'
    )

    foreach ($token in $forbiddenUpgrade) {
        if ($upgradeBody -match [regex]::Escape($token)) {
            Write-Host "  [FAIL] Proibido no fluxo de atualizacao: $token" -ForegroundColor Red
            $allOk = $false
        } else {
            Write-Host "  [OK] Ausente (correto): $token" -ForegroundColor Green
        }
    }
}

if ($moduleText -match 'Atualizar programas instalados') {
    Write-Host "  [OK] Opcao atualizar no menu" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Opcao atualizar ausente no menu" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""
if ($allOk) {
    Write-Host "[SUCESSO] test_software_upgrade concluido (sem atualizacao real)" -ForegroundColor Green
} else {
    Write-Host "[FALHA] Validacao do modulo de atualizacao" -ForegroundColor Red
    exit 1
}

Write-Host ""
