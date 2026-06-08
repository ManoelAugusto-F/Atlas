# ==========================================
# Atlas - Teste do Logger Operacional
# ==========================================

. "$PSScriptRoot/../modules/logger.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Logger operacional" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script:LoggerTestFailed = $false
$expectedLogsDir = Join-Path $env:ProgramData "Atlas\Logs"
$expectedLogPath = Join-Path $expectedLogsDir "atlas.log"
$expectedSessionsDir = Join-Path $expectedLogsDir "Sessions"

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

$required = @(
    'Initialize-AtlasLogger',
    'Write-AtlasLog',
    'Get-AtlasLogPath',
    'Start-AtlasSessionLog'
)

foreach ($fn in $required) {
    Test-Assert ([bool](Get-Command $fn -ErrorAction SilentlyContinue)) "Funcao $fn"
}

$loggerSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/logger.ps1") -Raw
Test-Assert ($loggerSource -notmatch '\.\./logs') "Logger nao usa caminho relativo ../logs"
Test-Assert ($loggerSource -notmatch 'logs/sessions') "Logger nao usa caminho relativo logs/sessions"
Test-Assert ($loggerSource -notmatch 'logs\\sessions') "Logger nao usa caminho relativo logs\sessions"

try {
    $script:AtlasOperationalLogPath = $null
    $script:AtlasLoggerInitialized = $false
    $script:AtlasSessionLogPath = $null
    $script:AtlasSessionActive = $false

    Test-Assert ((Get-AtlasLogPath) -eq $expectedLogPath) "Get-AtlasLogPath retorna C:\ProgramData\Atlas\Logs\atlas.log"

    $logPath = Initialize-AtlasLogger
    Test-Assert (Test-Path $expectedLogsDir) "Pasta C:\ProgramData\Atlas\Logs criada"
    Test-Assert (Test-Path $expectedSessionsDir) "Pasta C:\ProgramData\Atlas\Logs\Sessions criada"
    Test-Assert (Test-Path $logPath) "Arquivo atlas.log criado"
    Test-Assert ($logPath -eq $expectedLogPath) "Initialize-AtlasLogger usa ProgramData"
    Test-Assert ($logPath -eq (Get-AtlasLogPath)) "Get-AtlasLogPath retorna caminho correto"

    Write-AtlasLog -Nivel INFO -Modulo "Teste" -Acao "Escrita" -Resultado "Sucesso"
    $content = Get-Content -Path $logPath -Raw

    Test-Assert ($content -match "Teste") "Log contem modulo Teste"
    Test-Assert ($content -match "Escrita") "Log contem acao Escrita"
    Test-Assert ($content -match "Sucesso") "Log contem resultado Sucesso"
    Test-Assert ($content -match "\| INFO \|") "Log contem nivel INFO"

    $sessionLog = Start-AtlasSessionLog
    Test-Assert ($sessionLog.StartsWith($expectedSessionsDir)) "Log de sessao em ProgramData\Logs\Sessions"
    Test-Assert ($sessionLog -match 'session_\d{8}_\d{6}\.log$') "Nome do log de sessao no formato esperado"
    Test-Assert (Test-Path $sessionLog) "Arquivo de sessao criado"

    Write-AtlasSessionLog -Message "Teste de sessao" -Level "INFO"
    $sessionContent = Get-Content -Path $sessionLog -Raw
    Test-Assert ($sessionContent -match "Teste de sessao") "Log de sessao gravado com sucesso"

    $modulesDir = Join-Path $PSScriptRoot "../modules"
    $integrationChecks = @(
        @{ File = "cleanup.ps1";         Pattern = 'Modulo "Limpeza"' }
        @{ File = "network-tools.ps1";  Pattern = 'Modulo "Rede"' }
        @{ File = "software-install.ps1"; Pattern = 'Modulo "Instalacao"' }
        @{ File = "onedrive.ps1";        Pattern = 'Modulo "OneDrive"' }
        @{ File = "outlook.ps1";         Pattern = 'Modulo "Outlook"' }
        @{ File = "teams.ps1";           Pattern = 'Modulo "Teams"' }
        @{ File = "browser.ps1";         Pattern = 'Modulo "Navegadores"' }
        @{ File = "printer.ps1";         Pattern = 'Modulo "Impressoras"' }
        @{ File = "windows-repair.ps1";  Pattern = 'Modulo "Reparos Windows"' }
    )

    Write-Host ""
    Write-Host "Validando integracao Write-AtlasLog nos modulos..." -ForegroundColor Gray
    foreach ($check in $integrationChecks) {
        $filePath = Join-Path $modulesDir $check.File
        $raw = Get-Content -Path $filePath -Raw
        Test-Assert ($raw -match $check.Pattern) "Integracao $($check.File)"
    }
}
catch {
    Write-Host "[FAIL] Erro no teste: $_" -ForegroundColor Red
    $script:LoggerTestFailed = $true
}

Write-Host ""
if ($script:LoggerTestFailed) {
    Write-Host "[FALHA] test_logger.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCESSO] test_logger.ps1" -ForegroundColor Green
exit 0
