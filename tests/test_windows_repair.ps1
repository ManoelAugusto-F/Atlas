# ==========================================
# Atlas - Teste do Modulo Reparos Windows
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/windows-repair.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Reparos Windows e diagnostico guiado" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script:RepairTestFailed = $false

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if ($Condition) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:RepairTestFailed = $true
    }
}

$required = @(
    'Start-WindowsDiagnostic',
    'Show-WindowsRepairMenu',
    'Test-SfcVerifyOnly',
    'Invoke-SfcScannowSafe',
    'Test-DismCheckHealth',
    'Invoke-DismScanHealthSafe',
    'Invoke-DismRestoreHealthSafe',
    'Reset-WindowsUpdateSafe',
    'Show-AtlasDescribedOption'
)

foreach ($fn in $required) {
    Test-Assert ([bool](Get-Command $fn -ErrorAction SilentlyContinue)) "Funcao $fn"
}

$repairSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/windows-repair.ps1") -Raw
$menuSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/menu.ps1") -Raw
$cleanupSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/cleanup.ps1") -Raw

Test-Assert ($repairSource -match 'Show-AtlasDescribedOption') "Reparos Windows usa opcoes descritas"
Test-Assert ($repairSource -match 'Diagnostico recomendado') "Menu contem diagnostico recomendado"
Test-Assert ($repairSource -match 'Analisa o Windows e sugere o proximo passo') "Descricao do diagnostico presente"
Test-Assert ($repairSource -match 'Verificar arquivos do Windows') "Menu contem verificacao de arquivos"
Test-Assert ($repairSource -match 'Corrigir arquivos do Windows') "Menu contem correcao de arquivos"
Test-Assert ($repairSource -match 'Verificar imagem do Windows') "Menu contem verificacao de imagem"
Test-Assert ($repairSource -match 'Reparar imagem do Windows') "Menu contem reparo de imagem"
Test-Assert ($repairSource -match 'Resetar Windows Update') "Menu contem reset do Windows Update"
Test-Assert ($repairSource -notmatch '-Risk ') "Reparos Windows sem nivel de risco"
Test-Assert ($repairSource -match 'Start-WindowsDiagnostic') "Diagnostico guiado implementado"
Test-Assert ($repairSource -match 'Diagnostico do Sistema') "Resumo de diagnostico implementado"
Test-Assert ($repairSource -match 'SFC: Nao foi possivel executar esta verificacao sem privilegios de administrador\.') "SFC com mensagem de admin"
Test-Assert ($repairSource -match 'DISM: Nao foi possivel executar esta verificacao sem privilegios de administrador\.') "DISM com mensagem de admin"
Test-Assert ($repairSource -match 'REQUER_ADMIN') "Status REQUER_ADMIN implementado"
Test-Assert ($repairSource -match 'NAO_INTERPRETADO') "Status NAO_INTERPRETADO implementado"
Test-Assert ($repairSource -match 'NAO_EXECUTADO') "Status NAO_EXECUTADO implementado"
Test-Assert ($repairSource -notmatch 'Status = "unknown"') "Captura sem status unknown"
Test-Assert ($repairSource -notmatch '"unknown"') "Codigo sem string unknown"
Test-Assert ($repairSource -match 'Recomendacao: execute \[2\] Verificar arquivos do Windows\.') "Recomendacao SFC amigavel presente"
Test-Assert ($repairSource -match 'Recomendacao: execute \[4\] Verificar imagem do Windows\.') "Recomendacao DISM amigavel presente"

$diagnosticBody = ''
if ($repairSource -match '(?s)function Start-WindowsDiagnostic\s*\{(.+?)\r?\nfunction ') {
    $diagnosticBody = $Matches[1]
}
Test-Assert ($diagnosticBody -notmatch 'Write-Host.*unknown') "Saida final do diagnostico sem texto unknown"
Test-Assert ($diagnosticBody -notmatch 'Write-Atlas.*unknown') "Helpers de UI do diagnostico sem texto unknown"
Test-Assert ($diagnosticBody -match 'Diagnostico SFC:') "Log explicito de status SFC"
Test-Assert ($diagnosticBody -match 'Diagnostico DISM:') "Log explicito de status DISM"

Test-Assert ($menuSource -match 'Show-AtlasCompactOption') "Menu principal usa formato compacto"
Test-Assert ($menuSource -notmatch 'Show-AtlasDescribedOption') "Menu principal sem descricoes"
Test-Assert ($cleanupSource -match 'Show-AtlasCompactOption') "Limpeza usa formato compacto"
Test-Assert ($cleanupSource -notmatch 'Show-AtlasDescribedOption') "Limpeza sem descricoes"

Test-Assert ($repairSource -match '"1" \{ Start-WindowsDiagnostic') "Opcao 1 executa diagnostico"
Test-Assert ($repairSource -match '"2" \{ Test-SfcVerifyOnly') "Opcao 2 verifica arquivos"
Test-Assert ($repairSource -match '"3" \{ Invoke-SfcScannowSafe') "Opcao 3 corrige arquivos"
Test-Assert ($repairSource -match '"4" \{ Test-DismCheckHealth') "Opcao 4 verifica imagem"
Test-Assert ($repairSource -match '"5" \{ Invoke-DismRestoreHealthSafe') "Opcao 5 repara imagem"
Test-Assert ($repairSource -match '"6" \{ Reset-WindowsUpdateSafe') "Opcao 6 reseta Windows Update"

Write-Host ""
if ($script:RepairTestFailed) {
    Write-Host "[FALHA] test_windows_repair.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_windows_repair.ps1" -ForegroundColor Green
exit 0
