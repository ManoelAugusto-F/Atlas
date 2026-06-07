# ==========================================
# Atlas - Teste do Historico Operacional
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/history.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Historico operacional" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allOk = $true
$tempBase = if ($env:TEMP) { $env:TEMP } elseif ($env:TMP) { $env:TMP } else { [System.IO.Path]::GetTempPath() }
$testRoot = Join-Path $tempBase ("AtlasHistoryTest_" + [guid]::NewGuid().ToString())

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if ($Condition) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:HistoryTestFailed = $true
    }
}

$script:HistoryTestFailed = $false

$required = @(
    'Show-HistoryMenu',
    'Get-AtlasRecentLogs',
    'Open-AtlasLogFolder',
    'Clear-AtlasLogs'
)

foreach ($fn in $required) {
    Test-Assert ([bool](Get-Command $fn -ErrorAction SilentlyContinue)) "Funcao $fn"
}

try {
    Initialize-AtlasLogger -LogRoot $testRoot | Out-Null
    $logPath = Get-AtlasLogPath

    for ($i = 1; $i -le 60; $i++) {
        Write-AtlasLog -Nivel INFO -Modulo "Teste" -Acao "Evento $i" -Resultado "Sucesso"
    }

    $recent = Get-AtlasRecentLogs -Count 50
    Test-Assert ($recent.Count -eq 50) "Get-AtlasRecentLogs retorna 50 eventos"

    $lastLine = $recent[-1]
    Test-Assert ($lastLine -match "Evento 60") "Ultimo evento e o mais recente"

    Remove-Item -Path $logPath -Force -ErrorAction SilentlyContinue
    New-Item -ItemType File -Path $logPath -Force | Out-Null
    Write-AtlasLog -Nivel INFO -Modulo "Sistema" -Acao "Limpeza de Logs" -Resultado "Sucesso"

    $afterClear = @(Get-Content -Path $logPath | Where-Object { $_ -match '\S' })
    Test-Assert ($afterClear.Count -eq 1) "Log limpo mantem apenas entrada de limpeza"
    Test-Assert ($afterClear[0] -match "Limpeza de Logs") "Entrada de limpeza registrada"

    $sampleModules = @(
        @{ Modulo = "OneDrive"; Acao = "Consulta status" }
        @{ Modulo = "Outlook"; Acao = "Diagnostico" }
        @{ Modulo = "Teams"; Acao = "Limpeza cache" }
        @{ Modulo = "Navegadores"; Acao = "Chrome" }
        @{ Modulo = "Impressoras"; Acao = "Reinicio spooler" }
        @{ Modulo = "Reparos Windows"; Acao = "SFC Verify" }
    )

    Write-Host ""
    Write-Host "Simulando eventos dos modulos integrados..." -ForegroundColor Gray
    foreach ($sample in $sampleModules) {
        Write-AtlasLog -Nivel INFO -Modulo $sample.Modulo -Acao $sample.Acao -Resultado "Sucesso"
    }

    $merged = Get-Content -Path $logPath -Raw
    foreach ($sample in $sampleModules) {
        Test-Assert ($merged -match [regex]::Escape($sample.Modulo)) "Evento $($sample.Modulo) registrado"
        Test-Assert ($merged -match [regex]::Escape($sample.Acao)) "Acao $($sample.Acao) registrada"
    }
}
catch {
    Write-Host "[FAIL] Erro no teste: $_" -ForegroundColor Red
    $script:HistoryTestFailed = $true
}
finally {
    if (Test-Path $testRoot) {
        Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
if ($script:HistoryTestFailed) {
    Write-Host "[FALHA] test_history.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_history.ps1" -ForegroundColor Green
exit 0
