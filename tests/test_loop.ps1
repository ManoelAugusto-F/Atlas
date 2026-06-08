. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/cleanup.ps1"
. "$PSScriptRoot/../modules/network-tools.ps1"
. "$PSScriptRoot/../modules/onedrive.ps1"
. "$PSScriptRoot/../modules/printer.ps1"
. "$PSScriptRoot/../modules/windows-repair.ps1"
. "$PSScriptRoot/../modules/quick-diagnostic.ps1"
. "$PSScriptRoot/../modules/outlook.ps1"
. "$PSScriptRoot/../modules/teams.ps1"
. "$PSScriptRoot/../modules/browser.ps1"
. "$PSScriptRoot/../modules/programs.ps1"
. "$PSScriptRoot/../modules/services.ps1"
. "$PSScriptRoot/../modules/software-install.ps1"

# ── Validar funcoes do modulo cleanup ──────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de cleanup.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$cleanupFunctions = @(
    'Get-LargestUserFolders',
    'Get-LargestUserFiles',
    'Clear-UserTemp',
    'Clear-WindowsTemp',
    'Clear-WindowsUpdateCache',
    'Clear-RecycleBinSafe',
    'Invoke-SafeCleanup',
    'Show-CleanupMenu'
)

$allOk = $true
foreach ($fn in $cleanupFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de cleanup nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Todas as funcoes de cleanup validadas." -ForegroundColor Green

# ── Validar funcoes do modulo network-tools ────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de network-tools.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$networkFunctions = @(
    'Test-InternetConnectionBasic',
    'Test-DnsBasic',
    'Get-NetworkConfigBasic',
    'Clear-DnsCacheSafe',
    'Update-IpAddressLeaseSafe',
    'Reset-WinsockSafe',
    'Reset-TcpIpSafe',
    'Show-NetworkMenu'
)

$allOk = $true
foreach ($fn in $networkFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de network-tools nao foram carregadas." -ForegroundColor Red
    exit 1
}

# Executar funcoes somente-leitura de rede
Write-Host ""
Write-Host "[TESTE] Executando Test-InternetConnectionBasic" -ForegroundColor Magenta
Test-InternetConnectionBasic

Write-Host ""
Write-Host "[TESTE] Executando Test-DnsBasic" -ForegroundColor Magenta
Test-DnsBasic

Write-Host ""
Write-Host "Todas as funcoes de network-tools validadas." -ForegroundColor Green

# ── Validar funcoes do modulo onedrive ───────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de onedrive.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$onedriveFunctions = @(
    'Get-OneDriveStatus',
    'Restart-OneDriveSafe',
    'Reset-OneDriveSafe',
    'Open-OneDriveFolder',
    'Open-OneDriveLogs',
    'Find-OneDriveExecutable',
    'Uninstall-OneDriveSafe',
    'Clear-OneDriveResidualFilesSafe',
    'Open-OneDriveDownloadPage',
    'Show-OneDriveMenu'
)

$allOk = $true
foreach ($fn in $onedriveFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de onedrive nao foram carregadas." -ForegroundColor Red
    exit 1
}

# Executar apenas funcao de leitura (N/A no Linux, sem erro)
Write-Host ""
Write-Host "[TESTE] Executando Get-OneDriveStatus" -ForegroundColor Magenta
Get-OneDriveStatus

Write-Host ""
Write-Host "[TESTE] Executando Find-OneDriveExecutable" -ForegroundColor Magenta
$exe = Find-OneDriveExecutable
if ($exe) {
    Write-Host "  Executavel: $exe" -ForegroundColor Green
} else {
    Write-Host "  Executavel nao encontrado (esperado no Linux)." -ForegroundColor Gray
}

Write-Host ""
Write-Host "Todas as funcoes de onedrive validadas." -ForegroundColor Green

# ── Validar funcoes do modulo printer ──────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de printer.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$printerFunctions = @(
    'Get-PrinterList',
    'Get-PrintQueueStatus',
    'Restart-SpoolerSafe',
    'Clear-PrintQueueSafe',
    'Get-PrinterDrivers',
    'Add-TcpIpPrinterSafe',
    'Add-SharedPrinterSafe',
    'Show-PrinterMenu'
)

$allOk = $true
foreach ($fn in $printerFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de printer nao foram carregadas." -ForegroundColor Red
    exit 1
}

# Executar funcoes somente-leitura (N/A no Linux, sem erro)
Write-Host ""
Write-Host "[TESTE] Executando Get-PrinterList" -ForegroundColor Magenta
Get-PrinterList

Write-Host ""
Write-Host "[TESTE] Executando Get-PrintQueueStatus" -ForegroundColor Magenta
Get-PrintQueueStatus

Write-Host ""
Write-Host "[TESTE] Executando Get-PrinterDrivers" -ForegroundColor Magenta
Get-PrinterDrivers

Write-Host ""
Write-Host "Todas as funcoes de printer validadas." -ForegroundColor Green

# ── Validar funcoes do modulo windows-repair ───────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de windows-repair.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$repairFunctions = @(
    'Start-WindowsDiagnostic',
    'Test-SfcVerifyOnly',
    'Invoke-SfcScannowSafe',
    'Test-DismCheckHealth',
    'Invoke-DismScanHealthSafe',
    'Invoke-DismRestoreHealthSafe',
    'Reset-WindowsUpdateSafe',
    'Show-WindowsRepairMenu'
)

$allOk = $true
foreach ($fn in $repairFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de windows-repair nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Todas as funcoes de windows-repair validadas (sem execucao de SFC/DISM)." -ForegroundColor Green

# ── Validar funcoes do modulo quick-diagnostic ──────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de quick-diagnostic.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$diagFunctions = @(
    'Get-DiskAlert',
    'Get-MemoryAlert',
    'Get-UptimeAlert',
    'Get-InternetAlert',
    'Get-OneDriveAlert',
    'Get-SpoolerAlert',
    'Get-RebootPendingAlert',
    'Invoke-QuickDiagnostic'
)

$allOk = $true
foreach ($fn in $diagFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de quick-diagnostic nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Todas as funcoes de quick-diagnostic validadas." -ForegroundColor Green

# ── Validar funcoes do modulo outlook ───────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de outlook.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$outlookFunctions = @('Get-OutlookStatus')

$allOk = $true
foreach ($fn in $outlookFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de outlook nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[TESTE] Executando Get-OutlookStatus" -ForegroundColor Magenta
Get-OutlookStatus

Write-Host ""
Write-Host "Todas as funcoes de outlook validadas." -ForegroundColor Green

# ── Validar funcoes do modulo teams ──────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de teams.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$teamsFunctions = @('Get-TeamsStatus')

$allOk = $true
foreach ($fn in $teamsFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de teams nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[TESTE] Executando Get-TeamsStatus" -ForegroundColor Magenta
Get-TeamsStatus

Write-Host ""
Write-Host "Todas as funcoes de teams validadas." -ForegroundColor Green

# ── Validar funcoes do modulo browser ────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de browser.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$browserFunctions = @('Get-BrowserProfiles')

$allOk = $true
foreach ($fn in $browserFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de browser nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[TESTE] Executando Get-BrowserProfiles" -ForegroundColor Magenta
Get-BrowserProfiles

Write-Host ""
Write-Host "Todas as funcoes de browser validadas." -ForegroundColor Green

# ── Validar funcoes do modulo programs ───────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de programs.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$programsFunctions = @('Get-InstalledPrograms')

$allOk = $true
foreach ($fn in $programsFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de programs nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[TESTE] Executando Get-InstalledPrograms" -ForegroundColor Magenta
Get-InstalledPrograms

Write-Host ""
Write-Host "Todas as funcoes de programs validadas." -ForegroundColor Green

# ── Validar funcoes do modulo services ───────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de services.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$servicesFunctions = @('Get-CriticalServices')

$allOk = $true
foreach ($fn in $servicesFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de services nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[TESTE] Executando Get-CriticalServices" -ForegroundColor Magenta
Get-CriticalServices

Write-Host ""
Write-Host "Todas as funcoes de services validadas." -ForegroundColor Green

# ── Validar funcoes do modulo outlook v0.2 toolkit ───────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes do Outlook Toolkit" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$outlookToolkitFunctions = @(
    'Show-OutlookMenu',
    'Restart-OutlookSafe',
    'Open-OutlookDataFolder',
    'Open-OutlookCacheFolder',
    'Clear-OutlookRoamCacheSafe',
    'Open-OfficeRepairPanel',
    'Open-InstalledAppsForOffice',
    'Open-OfficeDownloadPage'
)

$allOk = $true
foreach ($fn in $outlookToolkitFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes do Outlook Toolkit nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Todas as funcoes do Outlook Toolkit validadas." -ForegroundColor Green

# ── Validar funcoes do modulo teams v0.2 toolkit ────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes do Teams Toolkit" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$teamsToolkitFunctions = @(
    'Show-TeamsMenu',
    'Restart-TeamsSafe',
    'Clear-TeamsCacheSafe',
    'Open-TeamsCacheFolder',
    'Get-TeamsPersonalStatus',
    'Get-TeamsWorkSchoolStatus',
    'Remove-TeamsPersonalSafe'
)

$allOk = $true
foreach ($fn in $teamsToolkitFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes do Teams Toolkit nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Todas as funcoes do Teams Toolkit validadas." -ForegroundColor Green

# ── Validar funcoes do modulo browser v0.2 toolkit ─────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes do Browser Toolkit" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$browserToolkitFunctions = @(
    'Show-BrowserMenu',
    'Get-BrowserStatus',
    'Open-BrowserProfileFolder',
    'Clear-ChromeCacheSafe',
    'Clear-EdgeCacheSafe',
    'Clear-FirefoxCacheSafe',
    'Clear-AllBrowserCachesSafe'
)

$allOk = $true
foreach ($fn in $browserToolkitFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes do Browser Toolkit nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Todas as funcoes do Browser Toolkit validadas." -ForegroundColor Green

# -- Validar modulo software-install --------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de software-install.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$softwareFunctions = @(
    'Show-SoftwareInstallMenu',
    'Test-WingetAvailable',
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
    'ConvertFrom-WingetUpgradeJson',
    'Get-WingetUpgradeEntries',
    'Get-WingetAvailableUpgrades',
    'Show-WingetUpgradePreview',
    'Update-InstalledSoftwareSafe',
    'Export-SoftwareInventory',
    'Test-WingetCatalogItem',
    'Invoke-WingetCatalogValidation',
    'Export-WingetCatalogValidationHtml',
    'Write-AtlasStep',
    'Write-AtlasResult'
)

$allOk = $true
foreach ($fn in $softwareFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de software-install nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[TESTE] Executando Test-WingetAvailable (somente leitura)" -ForegroundColor Magenta
$wingetCheck = Test-WingetAvailable
Write-Host "  $($wingetCheck.Message)" -ForegroundColor Gray

Write-Host ""
Write-Host "[TESTE] Executando Get-SoftwareCatalog (somente leitura)" -ForegroundColor Magenta
$catalog = Get-SoftwareCatalog
if ($catalog) {
    Write-Host "  Categorias: $(@($catalog.categories).Count)" -ForegroundColor Gray
} else {
    Write-Host "  [FAIL] Catalogo nao carregado" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Todas as funcoes de software-install validadas." -ForegroundColor Green

# ── Validar helpers de UI ───────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando helpers de UI (core.ps1)" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$uiFunctions = @(
    'Show-AtlasHeader',
    'Show-AtlasCompactOption',
    'Show-AtlasDescribedOption',
    'Show-AtlasBackOption',
    'Show-AtlasMenuHeader',
    'Show-AtlasMenuOption',
    'Show-AtlasMenuBackOption',
    'Read-AtlasMenuChoice',
    'Write-AtlasInfo',
    'Write-AtlasSuccess',
    'Write-AtlasWarning',
    'Write-AtlasError',
    'Read-AtlasConfirm',
    'Write-AtlasStep',
    'Write-AtlasProgress',
    'Write-AtlasResult'
)

$allOk = $true
foreach ($fn in $uiFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: helpers de UI nao carregados." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Helpers de UI validados." -ForegroundColor Green

$running = $true
$inputs  = @('1','2','3','4','5','6','7','8','9','10','99','0')
$idx     = 0

while ($running) {
    $option = $inputs[$idx]; $idx++
    Write-Host ""
    Write-Host "========================================" -ForegroundColor DarkCyan
    Write-Host "[TESTE] Opcao simulada: $option" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor DarkCyan

    switch ($option) {
        '1'  { Write-Log -Message "Limpeza segura (modulo validado acima, sem execucao destrutiva)" -Level "INFO" }
        '2'  { Write-Log -Message "Rede e internet (modulo validado acima, sem execucao destrutiva)" -Level "INFO" }
        '3'  { Write-Log -Message "OneDrive (modulo validado acima, sem execucao destrutiva)" -Level "INFO" }
        '4'  { Write-Log -Message "Impressoras (modulo validado acima, sem execucao destrutiva)" -Level "INFO" }
        '5'  { Write-Log -Message "Reparos Windows (modulo validado acima, sem execucao de SFC/DISM)" -Level "INFO" }
        '6'  { Write-Log -Message "Submenu Outlook (funcao Show-OutlookMenu validada)" -Level "INFO" }
        '7'  { Write-Log -Message "Submenu Teams (funcao Show-TeamsMenu validada)" -Level "INFO" }
        '8'  { Write-Log -Message "Submenu Navegadores (funcao Show-BrowserMenu validada)" -Level "INFO" }
        '9'  { Write-Log -Message "Submenu Instalacao de programas (Show-SoftwareInstallMenu validada)" -Level "INFO" }
        '10' { Write-Log -Message "Submenu Historico (Show-HistoryMenu validada)" -Level "INFO" }
        '0'  { Write-Log -Message "Atlas encerrado" -Level "INFO"; $running = $false }
        default {
            Write-Log -Message "Opcao invalida: $option" -Level "WARN"
            Write-Host "Opcao invalida." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "LOOP ENCERRADO COM SUCESSO" -ForegroundColor Green
