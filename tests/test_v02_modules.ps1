# Suite de Testes do Atlas - Validacao de Modulos da Sprint v0.2
# Compatibilidade: Rodar em Windows PowerShell 5.1 e PowerShell 7+
# Codificacao estrita: ASCII puro

# Importa o logger preliminarmente
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# Resolve módulos de forma relativa compatível com Windows e Linux
$loggerPath = Join-Path -Path $scriptDir -ChildPath "../modules/logger.ps1"
if (Test-Path $loggerPath) {
    . $loggerPath
} else {
    function Write-Log { param($Level, $Message) Write-Host "[$Level] $Message" }
}

Write-Host "============================================="
Write-Host " ATLAS - INICIANDO TESTES DA SPRINT v0.2"
Write-Host "============================================="

$failures = 0
$modulesToTest = @("outlook", "teams", "browser", "programs", "services")

foreach ($mod in $modulesToTest) {
    $modPath = Join-Path -Path $scriptDir -ChildPath "../modules/$mod.ps1"
    Write-Host -NoNewline "Testando carregamento e sintaxe do modulo '$mod'... "
    if (Test-Path $modPath) {
        try {
            # Faz o dot sourcing do modulo para validar o parse e importação direta
            . $modPath
            Write-Host "[OK]" -ForegroundColor Green
        } catch {
            Write-Host "[FALHA]" -ForegroundColor Red
            Write-Host "  Erro: $($_.Exception.Message)" -ForegroundColor DarkRed
            $failures++
        }
    } else {
        Write-Host "[NAO LOCALIZADO]" -ForegroundColor Red
        $failures++
    }
}

Write-Host "---------------------------------------------"
Write-Host "Validando existencia das novas funcoes publicas..."

$expectedFunctions = @(
    "Get-OutlookStatus", "Restart-OutlookProcess", "Get-OutlookProfiles",
    "Get-TeamsStatus", "Clear-TeamsCache",
    "Get-BrowserProfiles", "Clear-BrowserCache",
    "Get-InstalledPrograms", "Export-InstalledProgramsCsv",
    "Get-CriticalServices", "Get-StoppedAutomaticServices", "Restart-ServiceSafe"
)

foreach ($fn in $expectedFunctions) {
    Write-Host -NoNewline "Verificando funcao '$fn'... "
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host "[OK]" -ForegroundColor Green
    } else {
        # Como estamos rodando em mock/cross-platform, se o dot sourcing deu erro acima, a funcao nao existira
        Write-Host "[AUSENTE]" -ForegroundColor Red
        $failures++
    }
}

Write-Host "============================================="
if ($failures -eq 0) {
    Write-Host " TESTES CONCLUIDOS COM SUCESSO! 100% PASSOU" -ForegroundColor Green
    exit 0
} else {
    Write-Host " CONCLUIDO COM FALHAS. Total de erros: $failures" -ForegroundColor Red
    exit 1
}
