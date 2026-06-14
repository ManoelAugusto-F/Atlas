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
$tempBase = if ($env:TEMP) { $env:TEMP } elseif ($env:TMP) { $env:TMP } else { [System.IO.Path]::GetTempPath() }
$testRoot = Join-Path $tempBase ("AtlasLoggerTest_" + [guid]::NewGuid().ToString())
$expectedLogsDir = Join-Path $testRoot "Logs"
$expectedLogPath = Join-Path $expectedLogsDir "atlas.log"
$expectedSessionsDir = Join-Path $expectedLogsDir "Sessions"
$expectedWingetDir = Join-Path $expectedLogsDir "Winget"
$runningOnWindows = ($IsWindows -or $env:OS -eq 'Windows_NT')
$windowsLogsDir = if ($env:ProgramData) { Join-Path $env:ProgramData "Atlas\Logs" } else { $null }

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
    'Get-AtlasLogsRoot',
    'Get-AtlasLogPath',
    'Get-AtlasSessionLogsRoot',
    'Get-AtlasWingetLogsRoot',
    'Initialize-AtlasLogger',
    'Invoke-AtlasLegacyLogCleanup',
    'Invoke-AtlasLogRetention',
    'Write-AtlasLog',
    'Start-AtlasSessionLog',
    'Write-AtlasSessionLog',
    'Stop-AtlasSessionLog',
    'Write-Log'
)

foreach ($fn in $required) {
    Test-Assert ([bool](Get-Command $fn -ErrorAction SilentlyContinue)) "Funcao $fn"
}

$loggerSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/logger.ps1") -Raw
$projectRoot = Join-Path $PSScriptRoot ".."
$activeSources = @()
$scanDirs = @(
    (Join-Path $projectRoot "modules"),
    (Join-Path $projectRoot "bootstrap")
)
foreach ($dir in $scanDirs) {
    if (Test-Path $dir) {
        $activeSources += Get-ChildItem -Path $dir -Recurse -Include *.ps1 -File -ErrorAction SilentlyContinue
    }
}

Test-Assert ($loggerSource -match 'function Invoke-AtlasLegacyLogCleanup') "Limpeza de logs legados implementada"
Test-Assert ($loggerSource -match 'Initialize-AtlasLogger[\s\S]+Invoke-AtlasLegacyLogCleanup') "Initialize-AtlasLogger chama limpeza legada"
if ($loggerSource -match '(?s)function Write-Log\s*\{(.+?)\r?\n\}') {
    Test-Assert ($Matches[1] -notmatch 'provisionador\.log') "Write-Log nao grava provisionador.log"
} else {
    Test-Assert $false "Nao foi possivel validar corpo de Write-Log"
}
Test-Assert ($loggerSource -notmatch '\.\./logs') "Logger nao usa caminho relativo ../logs"
Test-Assert ($loggerSource -notmatch 'logs/sessions') "Logger nao usa caminho relativo logs/sessions"
Test-Assert ($loggerSource -notmatch 'logs\\sessions') "Logger nao usa caminho relativo logs\sessions"

$forbiddenRefs = @()
foreach ($file in $activeSources) {
    $raw = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($raw -match 'provisionador\.log') {
        if ($file.Name -ne 'logger.ps1') {
            $forbiddenRefs += $file.FullName
        }
    }
    if ($raw -match '(?<![A-Za-z])logs/sessions') {
        $forbiddenRefs += $file.FullName
    }
}
Test-Assert ($forbiddenRefs.Count -eq 0) "Sem referencias ativas a provisionador.log ou logs/sessions"

if ($runningOnWindows -and $windowsLogsDir) {
    $script:AtlasOperationalLogPath = $null
    $script:AtlasLogsDir = $null
    $script:AtlasLoggerInitialized = $false

    Test-Assert ((Join-Path $env:ProgramData "Atlas\Logs") -eq (Get-AtlasLogsRoot)) "Get-AtlasLogsRoot retorna C:\ProgramData\Atlas\Logs no Windows"
    Test-Assert ((Join-Path $env:ProgramData "Atlas\Logs\atlas.log") -eq (Get-AtlasLogPath)) "Get-AtlasLogPath retorna C:\ProgramData\Atlas\Logs\atlas.log no Windows"
    Test-Assert ((Join-Path $env:ProgramData "Atlas\Logs\Sessions") -eq (Get-AtlasSessionLogsRoot)) "Get-AtlasSessionLogsRoot retorna C:\ProgramData\Atlas\Logs\Sessions no Windows"
    Test-Assert ((Join-Path $env:ProgramData "Atlas\Logs\Winget") -eq (Get-AtlasWingetLogsRoot)) "Get-AtlasWingetLogsRoot retorna C:\ProgramData\Atlas\Logs\Winget no Windows"
} else {
    Write-Host "[INFO] Caminhos ProgramData validados apenas no Windows" -ForegroundColor Gray
}

try {
    $script:AtlasOperationalLogPath = $null
    $script:AtlasLogsDir = $null
    $script:AtlasLoggerInitialized = $false
    $script:AtlasSessionLogPath = $null
    $script:AtlasSessionActive = $false

    $logPath = Initialize-AtlasLogger -LogRoot $testRoot
    Test-Assert (Test-Path $expectedLogsDir) "Pasta Logs criada"
    Test-Assert (Test-Path $expectedSessionsDir) "Pasta Sessions criada"
    Test-Assert (Test-Path $expectedWingetDir) "Pasta Winget criada"
    Test-Assert (Test-Path $logPath) "Arquivo atlas.log criado"
    Test-Assert ($logPath -eq $expectedLogPath) "Initialize-AtlasLogger usa atlas.log"
    Test-Assert ((Get-AtlasLogsRoot) -eq $expectedLogsDir) "Get-AtlasLogsRoot retorna pasta Logs do teste"
    Test-Assert ((Get-AtlasLogPath) -eq $expectedLogPath) "Get-AtlasLogPath retorna caminho correto"
    Test-Assert ((Get-AtlasSessionLogsRoot) -eq $expectedSessionsDir) "Get-AtlasSessionLogsRoot retorna Sessions"
    Test-Assert ((Get-AtlasWingetLogsRoot) -eq $expectedWingetDir) "Get-AtlasWingetLogsRoot retorna Winget"

    Write-Host ""
    Write-Host "[TESTE] Invoke-AtlasLegacyLogCleanup" -ForegroundColor Magenta

    $legacyTestRoot = Join-Path $tempBase ("AtlasLegacyCleanup_" + [guid]::NewGuid().ToString())
    $legacyLogsDir = Join-Path $legacyTestRoot "Logs"
    $legacyWingetDir = Join-Path $legacyLogsDir "Winget"
    New-Item -ItemType Directory -Path $legacyWingetDir -Force | Out-Null

    $fakeProvisionador = Join-Path $legacyLogsDir "provisionador.log"
    $fakeWingetRoot = Join-Path $legacyLogsDir "winget_legacy.log"
    Set-Content -Path $fakeProvisionador -Value "legado provisionador" -Encoding UTF8
    Set-Content -Path $fakeWingetRoot -Value "winget antigo na raiz" -Encoding UTF8

    $script:AtlasOperationalLogPath = $null
    $script:AtlasLogsDir = $null
    $script:AtlasLoggerInitialized = $false

    Initialize-AtlasLogger -LogRoot $legacyTestRoot | Out-Null

    $movedWingetPath = Join-Path $legacyWingetDir "winget_legacy.log"
    Test-Assert (-not (Test-Path $fakeProvisionador)) "provisionador.log removido apos Initialize-AtlasLogger"
    Test-Assert (-not (Test-Path $fakeWingetRoot)) "winget_legacy.log removido da raiz de Logs"
    Test-Assert (Test-Path $movedWingetPath) "winget_legacy.log movido para Winget"

    $duplicateRoot = Join-Path $legacyLogsDir "winget_duplicado.log"
    $duplicateDest = Join-Path $legacyWingetDir "winget_duplicado.log"
    Set-Content -Path $duplicateDest -Value "ja existe" -Encoding UTF8
    Set-Content -Path $duplicateRoot -Value "duplicado na raiz" -Encoding UTF8
    Invoke-AtlasLegacyLogCleanup
    Test-Assert (-not (Test-Path $duplicateRoot)) "winget duplicado na raiz removido quando ja existe em Winget"

    if (Test-Path $legacyTestRoot) {
        Remove-Item -Path $legacyTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    $script:AtlasOperationalLogPath = $null
    $script:AtlasLogsDir = $null
    $script:AtlasLoggerInitialized = $false
    $script:AtlasSessionLogPath = $null
    $script:AtlasSessionActive = $false

    $logPath = Initialize-AtlasLogger -LogRoot $testRoot

    Write-AtlasLog -Nivel INFO -Modulo "Teste" -Acao "Escrita" -Resultado "Sucesso"
    $content = Get-Content -Path $logPath -Raw
    Test-Assert ($content -match "Teste") "Log contem modulo Teste"
    Test-Assert ($content -match "Escrita") "Log contem acao Escrita"
    Test-Assert ($content -match "Sucesso") "Log contem resultado Sucesso"
    Test-Assert ($content -match "\| INFO \|") "Log contem nivel INFO"

    $sessionLog = Start-AtlasSessionLog
    Test-Assert ($sessionLog.StartsWith($expectedSessionsDir)) "Log de sessao em Logs\Sessions"
    Test-Assert ($sessionLog -match 'session_\d{8}_\d{6}\.log$') "Nome do log de sessao no formato esperado"
    Test-Assert (Test-Path $sessionLog) "Arquivo de sessao criado"

    Write-AtlasSessionLog -Message "Teste de sessao" -Level "INFO"
    $sessionContent = Get-Content -Path $sessionLog -Raw
    Test-Assert ($sessionContent -match "Teste de sessao") "Log de sessao gravado com sucesso"

    Write-Log -Message "Teste Write-Log wrapper" -Level "INFO"
    $provisionadorPath = Join-Path $expectedLogsDir "provisionador.log"
    Test-Assert (-not (Test-Path $provisionadorPath)) "Write-Log nao cria provisionador.log"
    $sessionAfterWriteLog = Get-Content -Path $sessionLog -Raw
    Test-Assert ($sessionAfterWriteLog -match "Teste Write-Log wrapper") "Write-Log grava no session log"

    for ($i = 1; $i -le 35; $i++) {
        $file = Join-Path $expectedSessionsDir ("session_retention_{0:D2}.log" -f $i)
        Set-Content -Path $file -Value "retencao $i" -Encoding UTF8
        (Get-Item $file).LastWriteTime = (Get-Date).AddMinutes(-$i)
    }
    for ($i = 1; $i -le 35; $i++) {
        $file = Join-Path $expectedWingetDir ("winget_install_retention_{0:D2}.log" -f $i)
        Set-Content -Path $file -Value "winget $i" -Encoding UTF8
        (Get-Item $file).LastWriteTime = (Get-Date).AddMinutes(-$i)
    }

    Invoke-AtlasLogRetention -MaxFiles 30
    $sessionCount = @(Get-ChildItem -Path $expectedSessionsDir -File).Count
    $wingetCount = @(Get-ChildItem -Path $expectedWingetDir -File).Count
    Test-Assert ($sessionCount -eq 30) "Retencao Sessions mantem 30 arquivos (obteve $sessionCount)"
    Test-Assert ($wingetCount -eq 30) "Retencao Winget mantem 30 arquivos (obteve $wingetCount)"

    $softwareInstallSource = Get-Content -Path (Join-Path $PSScriptRoot "../modules/software-install.ps1") -Raw
    Test-Assert ($softwareInstallSource -match 'Get-AtlasWingetLogsRoot') "software-install usa Get-AtlasWingetLogsRoot"
    Test-Assert ($softwareInstallSource -notmatch 'Get-WingetLogsDirectory') "software-install sem Get-WingetLogsDirectory local"

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
