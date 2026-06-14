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
    'Test-WingetOperationSucceeded',
    'Test-WingetNoUpdatesAvailable',
    'Invoke-WingetManaged',
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

if (-not (Get-Command Show-AtlasProgressBar -ErrorAction SilentlyContinue)) {
    Write-Host "[OK] Show-AtlasProgressBar removida" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Show-AtlasProgressBar ainda presente" -ForegroundColor Red
    $allOk = $false
}

$removed = @(
    'Invoke-WingetWithLoading',
    'Invoke-WingetVisible',
    'Show-AtlasProgressBar'
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
        'WaitForExit',
        'Get-WingetLogsDirectory'
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
        'Show-AtlasProgressBar',
        'Percent',
        'spinner',
        'Start-Sleep -Milliseconds 500',
        'ConvertFrom-Json',
        '--output json'
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

Write-Host ""
Write-Host "[TESTE] Fluxo Update-InstalledSoftwareSafe (analise de arquivo)" -ForegroundColor Magenta

if ($moduleText -notmatch '(?s)function Update-InstalledSoftwareSafe\s*\{(.+?)\r?\nfunction ') {
    Write-Host "  [FAIL] Nao foi possivel extrair Update-InstalledSoftwareSafe" -ForegroundColor Red
    $allOk = $false
} else {
    $upgradeBody = $Matches[1]

    $requiredUpgrade = @(
        'Invoke-WingetManaged',
        'Test-WingetOperationSucceeded',
        'Test-WingetNoUpdatesAvailable',
        'ATLAS - ATUALIZACAO DE PROGRAMAS',
        'winget upgrade --all',
        'Executar atualizacao agora? [S/N]',
        'Executando Winget...',
        'Atualizacao concluida com sucesso.',
        '[AVISO] Nenhuma atualizacao disponivel.',
        '[ERRO] Falha na atualizacao.',
        'Verifique o log:',
        'Nenhuma atualizacao disponivel'
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
        'Show-AtlasProgressBar',
        '$exitCode -eq 0',
        'ExitCode -eq 0',
        'ConvertFrom-Json',
        '--output json',
        'Parse-WingetUpgradeList'
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
Write-Host "[TESTE] Test-WingetNoUpdatesAvailable (casos)" -ForegroundColor Magenta

$testLogDir = Join-Path ($(if ($env:TEMP) { $env:TEMP } else { '/tmp' })) "atlas_winget_upgrade_test_$(Get-Random)"
New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null

function Test-WingetNoUpdateCase {
    param(
        [string]$Name,
        [string]$LogContent,
        [bool]$Expected
    )

    $logFile = Join-Path $testLogDir "$Name.log"
    Set-Content -Path $logFile -Value $LogContent -Encoding UTF8

    $result = Test-WingetNoUpdatesAvailable -LogPath $logFile
    if ($result -eq $Expected) {
        Write-Host "  [OK] $Name" -ForegroundColor Green
        return $true
    }

    Write-Host "  [FAIL] $Name (esperado $Expected, obteve $result)" -ForegroundColor Red
    return $false
}

$noUpdateLog = 'Nenhum pacote instalado foi encontrado que corresponda aos critérios de entrada.'
if (-not (Test-WingetNoUpdateCase -Name 'Caso1_SemPacotesPt' -LogContent $noUpdateLog -Expected $true)) { $allOk = $false }
if (-not (Test-WingetNoUpdateCase -Name 'Caso2_NoInstalledPackageEn' -LogContent 'No installed package found matching input criteria' -Expected $true)) { $allOk = $false }
if (-not (Test-WingetNoUpdateCase -Name 'Caso3_NoAvailableUpgrade' -LogContent 'No available upgrade found' -Expected $true)) { $allOk = $false }
if (-not (Test-WingetNoUpdateCase -Name 'Caso4_SemFraseNoUpdate' -LogContent 'erro generico' -Expected $false)) { $allOk = $false }

Remove-Item -Path $testLogDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[TESTE] Test-WingetOperationSucceeded upgrade (casos)" -ForegroundColor Magenta

$upgradeTestDir = Join-Path ($(if ($env:TEMP) { $env:TEMP } else { '/tmp' })) "atlas_winget_success_test_$(Get-Random)"
New-Item -ItemType Directory -Path $upgradeTestDir -Force | Out-Null

$successLog = Join-Path $upgradeTestDir 'success.log'
Set-Content -Path $successLog -Value 'Instalado com êxito' -Encoding UTF8
$successResult = Test-WingetOperationSucceeded -ExitCode 1 -LogPath $successLog
if ($successResult) {
    Write-Host "  [OK] Exit1_InstaladoExito = SUCESSO" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Exit1_InstaladoExito deveria ser SUCESSO" -ForegroundColor Red
    $allOk = $false
}

Remove-Item -Path $upgradeTestDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($allOk) {
    Write-Host "[SUCESSO] test_software_upgrade concluido (sem atualizacao real)" -ForegroundColor Green
} else {
    Write-Host "[FALHA] Validacao do modulo de atualizacao" -ForegroundColor Red
    exit 1
}

Write-Host ""
