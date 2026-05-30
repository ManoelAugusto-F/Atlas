. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/cleanup.ps1"
. "$PSScriptRoot/../modules/network-tools.ps1"

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
        '4'  { Show-FeaturePlaceholder -FeatureName "OneDrive" }
        '5'  { Show-FeaturePlaceholder -FeatureName "Impressoras" }
        '6'  { Show-FeaturePlaceholder -FeatureName "Reparos Windows" }
        '7'  { Show-FeaturePlaceholder -FeatureName "Relatorio de suporte" }
        '0'  { Write-Log -Message "Atlas encerrado" -Level "INFO"; $running = $false }
        default {
            Write-Log -Message "Opcao invalida: $option" -Level "WARN"
            Write-Host "Opcao invalida." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "LOOP ENCERRADO COM SUCESSO" -ForegroundColor Green
