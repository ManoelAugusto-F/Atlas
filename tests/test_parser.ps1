# ==========================================
# Atlas - Teste de Sintaxe e Parser de Modulos
# ==========================================

$modules = @(
    "quick-diagnostic.ps1",
    "onedrive.ps1",
    "printer.ps1"
)

$modulesDir = Join-Path $PSScriptRoot "../modules"
$allOk = $true

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Atlas - Teste de Parser de Modulos" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

foreach ($mod in $modules) {
    $filePath = Join-Path $modulesDir $mod
    
    if (-not (Test-Path $filePath)) {
        Write-Host "  [ERRO] Arquivo nao encontrado: $mod" -ForegroundColor Red
        $allOk = $false
        continue
    }

    try {
        $content = Get-Content $filePath -Raw
        $null = [scriptblock]::Create($content)
        Write-Host "  [OK] Parser do arquivo: $mod" -ForegroundColor Green
    } catch {
        Write-Host "  [ERRO] Falha de parser no arquivo: $mod" -ForegroundColor Red
        Write-Host "    Detalhe: $_" -ForegroundColor Yellow
        $allOk = $false
    }
}

Write-Host "==========================================" -ForegroundColor Cyan

if (-not $allOk) {
    Write-Host "Falha no teste de parser: Um ou mais modulos possuem problemas de sintaxe!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Sucesso: Todos os modulos foram parseados corretamente!" -ForegroundColor Green
    exit 0
}
