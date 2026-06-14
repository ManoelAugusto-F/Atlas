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
    'Invoke-WingetManaged',
    'Show-AtlasProgressBar',
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
Write-Host "[TESTE] Invoke-WingetManaged (analise de arquivo)" -ForegroundColor Magenta

if ($moduleText -notmatch '(?s)function Invoke-WingetManaged\s*\{(.+?)\r?\nfunction ') {
    Write-Host "  [FAIL] Nao foi possivel extrair Invoke-WingetManaged" -ForegroundColor Red
    $allOk = $false
} else {
    $managedBody = $Matches[1]

    $requiredManaged = @(
        'Start-Process',
        'RedirectStandardOutput',
        'RedirectStandardError',
        'ExitCode',
        'Get-WingetLogsDirectory',
        'Show-AtlasProgressBar',
        'Get-Command winget -ErrorAction SilentlyContinue'
    )

    foreach ($token in $requiredManaged) {
        if ($managedBody -match [regex]::Escape($token)) {
            Write-Host "  [OK] Contem: $token" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Ausente: $token" -ForegroundColor Red
            $allOk = $false
        }
    }

    $forbiddenManaged = @(
        'ConvertFrom-Json',
        '--output json',
        '$env:ComSpec',
        'cmd.exe',
        'Parse-WingetUpgradeList',
        'Update-WingetPackageVisible'
    )

    foreach ($token in $forbiddenManaged) {
        if ($managedBody -match [regex]::Escape($token)) {
            Write-Host "  [FAIL] Proibido em Invoke-WingetManaged: $token" -ForegroundColor Red
            $allOk = $false
        } else {
            Write-Host "  [OK] Ausente (correto): $token" -ForegroundColor Green
        }
    }
}

if ($moduleText -match 'Atlas\\Logs\\Winget') {
    Write-Host "  [OK] Pasta de logs Winget definida" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Pasta Atlas\Logs\Winget ausente no modulo" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""
Write-Host "[TESTE] Fluxo Update-InstalledSoftwareSafe (analise de arquivo)" -ForegroundColor Magenta

if ($moduleText -notmatch '(?s)function Update-InstalledSoftwareSafe\s*\{(.+?)\r?\nfunction ') {
    Write-Host "  [FAIL] Nao foi possivel extrair Update-InstalledSoftwareSafe" -ForegroundColor Red
    $allOk = $false
} else {
    $upgradeBody = $Matches[1]

    $requiredUpgrade = @(
        'Invoke-WingetManaged',
        'ATLAS - ATUALIZACAO DE PROGRAMAS',
        'winget upgrade --all',
        'Executar atualizacao agora? [S/N]',
        'Atualizando programas',
        '[OK] Atualizacao concluida.',
        '[ERRO] Falha na atualizacao.',
        'Codigo de saida:',
        'Log:'
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
        '*> $null',
        '$LASTEXITCODE',
        'ConvertFrom-Json',
        '--output json',
        '$env:ComSpec',
        'cmd.exe',
        'Parse-WingetUpgradeList',
        'Update-WingetPackageVisible',
        'Show-WingetUpgradeSummary',
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
