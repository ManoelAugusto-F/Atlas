# ==========================================
# Atlas - Teste Instalacao de Programas
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/software-install.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] software-install.ps1 MVP" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$functions = @(
    'Show-SoftwareInstallMenu',
    'Test-WingetAvailable',
    'Test-WingetOperationSucceeded',
    'Invoke-WingetManaged',
    'Install-SoftwareByWingetSafe',
    'Get-SoftwareCatalog',
    'Get-SoftwareCategory',
    'Get-SoftwareItem',
    'Show-SoftwareCategoryMenu',
    'Install-RsatFullSafe',
    'Test-Microsoft365WingetAvailable',
    'Test-Microsoft365Installed',
    'Install-Microsoft365AppsSafe',
    'Repair-Microsoft365Safe',
    'Open-Microsoft365InstallPage',
    'Show-Microsoft365Menu',
    'Update-InstalledSoftwareSafe',
    'Export-SoftwareInventory',
    'Test-WingetCatalogItem',
    'Invoke-WingetCatalogValidation',
    'Export-WingetCatalogValidationHtml',
    'Write-AtlasStep',
    'Write-AtlasResult'
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

if (-not $allOk) {
    exit 1
}

Write-Host ""
Write-Host "[TESTE] Test-WingetOperationSucceeded (casos)" -ForegroundColor Magenta

$testLogDir = Join-Path ($(if ($env:TEMP) { $env:TEMP } else { '/tmp' })) "atlas_winget_test_$(Get-Random)"
New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null

function Test-WingetSuccessCase {
    param(
        [string]$Name,
        [int]$ExitCode,
        [string]$LogContent,
        [bool]$Expected
    )

    $logFile = Join-Path $testLogDir "$Name.log"
    if ($LogContent) {
        Set-Content -Path $logFile -Value $LogContent -Encoding UTF8
    } else {
        Set-Content -Path $logFile -Value "sem resultado" -Encoding UTF8
    }

    $result = Test-WingetOperationSucceeded -ExitCode $ExitCode -LogPath $logFile
    if ($result -eq $Expected) {
        Write-Host "  [OK] $Name" -ForegroundColor Green
        return $true
    }

    Write-Host "  [FAIL] $Name (esperado $Expected, obteve $result)" -ForegroundColor Red
    return $false
}

if (-not (Test-WingetSuccessCase -Name 'Caso1_Exit1_InstaladoExito' -ExitCode 1 -LogContent 'Instalado com êxito' -Expected $true)) { $allOk = $false }
if (-not (Test-WingetSuccessCase -Name 'Caso2_Exit1_SuccessfullyInstalled' -ExitCode 1 -LogContent 'Successfully installed' -Expected $true)) { $allOk = $false }
if (-not (Test-WingetSuccessCase -Name 'Caso3_Exit0_SemTexto' -ExitCode 0 -LogContent 'processo finalizado' -Expected $true)) { $allOk = $false }
if (-not (Test-WingetSuccessCase -Name 'Caso4_Exit1_SemTextoSucesso' -ExitCode 1 -LogContent 'erro generico' -Expected $false)) { $allOk = $false }

Remove-Item -Path $testLogDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[TESTE] Test-WingetAvailable (somente leitura)" -ForegroundColor Magenta
$result = Test-WingetAvailable
Write-Host "  Disponivel: $($result.Available)" -ForegroundColor Gray
Write-Host "  Mensagem  : $($result.Message)" -ForegroundColor Gray

Write-Host ""
Write-Host "[TESTE] Get-SoftwareCatalog (somente leitura)" -ForegroundColor Magenta
$catalog = Get-SoftwareCatalog
if (-not $catalog -or -not $catalog.categories) {
    Write-Host "[FAIL] Catalogo nao carregado" -ForegroundColor Red
    exit 1
}

$catCount = @($catalog.categories).Count
$itemCount = 0
foreach ($cat in $catalog.categories) {
    $itemCount += @($cat.items).Count
}
Write-Host "  Categorias: $catCount" -ForegroundColor Gray
Write-Host "  Programas : $itemCount" -ForegroundColor Gray

$modulePath = Join-Path $PSScriptRoot "../modules/software-install.ps1"
$moduleText = Get-Content $modulePath -Raw

Write-Host ""
Write-Host "[TESTE] Fluxo Install-SoftwareByWingetSafe (analise de arquivo)" -ForegroundColor Magenta

if ($moduleText -notmatch '(?s)function Install-SoftwareByWingetSafe\s*\{(.+?)\r?\nfunction ') {
    Write-Host "  [FAIL] Nao foi possivel extrair Install-SoftwareByWingetSafe" -ForegroundColor Red
    $allOk = $false
} else {
    $installBody = $Matches[1]

    $requiredInstall = @(
        'Invoke-WingetManaged',
        'Test-WingetOperationSucceeded',
        'ATLAS - INSTALACAO',
        'Executando Winget...',
        'instalado com sucesso.',
        '[ERRO] Falha na instalacao.',
        'Verifique o log:'
    )

    foreach ($token in $requiredInstall) {
        if ($installBody -match [regex]::Escape($token)) {
            Write-Host "  [OK] Contem: $token" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Ausente: $token" -ForegroundColor Red
            $allOk = $false
        }
    }

    $forbiddenInstall = @(
        'Show-AtlasProgressBar',
        'Executando Winget... %',
        'Status: executando winget',
        '$exitCode -eq 0',
        'ExitCode -eq 0',
        'ConvertFrom-Json',
        '--output json'
    )

    foreach ($token in $forbiddenInstall) {
        if ($installBody -match [regex]::Escape($token)) {
            Write-Host "  [FAIL] Proibido no fluxo de instalacao: $token" -ForegroundColor Red
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
if ($allOk) {
    Write-Host "[SUCESSO] test_software_install concluido (sem instalacao real)" -ForegroundColor Green
} else {
    Write-Host "[FALHA] Validacao do modulo de instalacao" -ForegroundColor Red
    exit 1
}

Write-Host ""
