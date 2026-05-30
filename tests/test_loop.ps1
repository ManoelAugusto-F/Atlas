. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/cleanup.ps1"
. "$PSScriptRoot/../modules/network-tools.ps1"
. "$PSScriptRoot/../modules/onedrive.ps1"
. "$PSScriptRoot/../modules/printer.ps1"
. "$PSScriptRoot/../modules/windows-repair.ps1"
. "$PSScriptRoot/../modules/support-report.ps1"

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
    'Renew-IpAddressSafe',
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

# ── Validar funcoes do modulo support-report ───────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[TESTE] Validando funcoes de support-report.ps1" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor DarkCyan

$supportFunctions = @('New-AtlasSupportReport')

$allOk = $true
foreach ($fn in $supportFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $fn" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $fn nao encontrada" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "FALHA: uma ou mais funcoes de support-report nao foram carregadas." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Todas as funcoes de support-report validadas." -ForegroundColor Green

$running = $true
$inputs  = @('1','2','3','4','5','6','7','99','0')
$idx     = 0

while ($running) {
    $option = $inputs[$idx]; $idx++
    Write-Host ""
    Write-Host "========================================" -ForegroundColor DarkCyan
    Write-Host "[TESTE] Opcao simulada: $option" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor DarkCyan

    switch ($option) {
        '1'  { Show-FeaturePlaceholder -FeatureName "Diagnostico rapido" }
        '2'  { Write-Log -Message "Limpeza segura (modulo validado acima, sem execucao destrutiva)" -Level "INFO" }
        '3'  { Write-Log -Message "Rede e internet (modulo validado acima, sem execucao destrutiva)" -Level "INFO" }
        '4'  { Write-Log -Message "OneDrive (modulo validado acima, sem execucao destrutiva)" -Level "INFO" }
        '5'  { Write-Log -Message "Impressoras (modulo validado acima, sem execucao destrutiva)" -Level "INFO" }
        '6'  { Write-Log -Message "Reparos Windows (modulo validado acima, sem execucao de SFC/DISM)" -Level "INFO" }
        '7'  { New-AtlasSupportReport }
        '0'  { Write-Log -Message "Atlas encerrado" -Level "INFO"; $running = $false }
        default {
            Write-Log -Message "Opcao invalida: $option" -Level "WARN"
            Write-Host "Opcao invalida." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "LOOP ENCERRADO COM SUCESSO" -ForegroundColor Green
