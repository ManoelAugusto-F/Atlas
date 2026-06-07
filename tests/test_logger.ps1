# ==========================================
# Atlas - Teste do Logger Operacional
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Logger operacional" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allOk = $true
$tempBase = if ($env:TEMP) { $env:TEMP } elseif ($env:TMP) { $env:TMP } else { [System.IO.Path]::GetTempPath() }
$testRoot = Join-Path $tempBase ("AtlasLoggerTest_" + [guid]::NewGuid().ToString())

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Name
    )
    if ($Condition) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:LoggerTestFailed = $true
    }
}

$script:LoggerTestFailed = $false

$required = @(
    'Initialize-AtlasLogger',
    'Write-AtlasLog',
    'Get-AtlasLogPath'
)

foreach ($fn in $required) {
    Test-Assert ([bool](Get-Command $fn -ErrorAction SilentlyContinue)) "Funcao $fn"
}

try {
    $logPath = Initialize-AtlasLogger -LogRoot $testRoot
    $logsDir = Join-Path $testRoot "Logs"

    Test-Assert (Test-Path $logsDir) "Pasta Logs criada"
    Test-Assert (Test-Path $logPath) "Arquivo atlas.log criado"
    Test-Assert ($logPath -eq (Get-AtlasLogPath)) "Get-AtlasLogPath retorna caminho correto"

    Write-AtlasLog -Nivel INFO -Modulo "Teste" -Acao "Escrita" -Resultado "Sucesso"
    $content = Get-Content -Path $logPath -Raw

    Test-Assert ($content -match "Teste") "Log contem modulo Teste"
    Test-Assert ($content -match "Escrita") "Log contem acao Escrita"
    Test-Assert ($content -match "Sucesso") "Log contem resultado Sucesso"
    Test-Assert ($content -match "\| INFO \|") "Log contem nivel INFO"
}
catch {
    Write-Host "[FAIL] Erro no teste: $_" -ForegroundColor Red
    $script:LoggerTestFailed = $true
}
finally {
    if (Test-Path $testRoot) {
        Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
if ($script:LoggerTestFailed) {
    Write-Host "[FALHA] test_logger.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_logger.ps1" -ForegroundColor Green
exit 0
