# ==========================================
# Atlas - Teste Validacao Candidatos Winget
# ==========================================

$ErrorActionPreference = "Stop"

function Get-SoftwareCandidates {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $candidatesPath = Join-Path $repoRoot "config/software-candidates.json"
    if (-not (Test-Path $candidatesPath)) {
        throw "Arquivo de candidatos nao encontrado: $candidatesPath"
    }

    $raw = Get-Content -Path $candidatesPath -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
}

function Test-WingetCandidateItem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )

    & winget show --id $PackageId --exact
    return ($LASTEXITCODE -eq 0)
}

function Export-WingetCandidatesValidationHtml {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results
    )

    $total = $Results.Count
    $okCount = @($Results | Where-Object { $_.Status -eq "OK" }).Count
    $errCount = @($Results | Where-Object { $_.Status -eq "ERRO" }).Count

    $rows = ""
    foreach ($r in $Results) {
        $statusClass = if ($r.Status -eq "OK") { "ok" } else { "erro" }
        $safeCat = ($r.Category -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
        $safeName = ($r.Name -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
        $safeId = ($r.Id -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
        $rows += "<tr class=""$statusClass""><td>$safeCat</td><td>$safeName</td><td>$safeId</td><td>$($r.Status)</td></tr>`n"
    }

    $generated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $html = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Atlas - Validacao Candidatos Winget</title>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; background: #f5f6f8; color: #222; }
        .wrap { max-width: 960px; margin: 0 auto; background: #fff; padding: 24px; border-radius: 8px; }
        h1 { color: #364fc7; }
        .summary { display: flex; gap: 16px; margin: 20px 0; }
        .card { flex: 1; padding: 14px; border-radius: 6px; background: #f1f3f5; }
        table { width: 100%; border-collapse: collapse; font-size: 14px; }
        th, td { padding: 10px; border-bottom: 1px solid #e9ecef; text-align: left; }
        th { background: #f8f9fa; }
        tr.ok td:last-child { color: #2b8a3e; font-weight: bold; }
        tr.erro td:last-child { color: #c92a2a; font-weight: bold; }
    </style>
</head>
<body>
<div class="wrap">
    <h1>Atlas - Validacao de Candidatos Winget</h1>
    <p>Gerado em: $generated</p>
    <div class="summary">
        <div class="card"><strong>Total</strong><br/>$total</div>
        <div class="card"><strong>OK</strong><br/>$okCount</div>
        <div class="card"><strong>Erro</strong><br/>$errCount</div>
    </div>
    <table>
        <thead><tr><th>Categoria</th><th>Nome</th><th>ID</th><th>Status</th></tr></thead>
        <tbody>
        $rows
        </tbody>
    </table>
</div>
</body>
</html>
"@

    $repoRoot = Split-Path $PSScriptRoot -Parent
    $reportsDir = Join-Path $repoRoot "reports"
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }

    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputPath = Join-Path $reportsDir "winget_candidates_validation_$ts.html"
    Set-Content -Path $outputPath -Value $html -Encoding UTF8
    return $outputPath
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TESTE] Validacao candidatos winget" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    $null = Get-Command winget -ErrorAction Stop
} catch {
    Write-Host "[ERRO] winget nao encontrado neste ambiente." -ForegroundColor Red
    Write-Host "       Instale o App Installer da Microsoft Store ou execute no Windows." -ForegroundColor Yellow
    exit 1
}

$candidates = Get-SoftwareCandidates
if (-not $candidates -or -not $candidates.categories) {
    Write-Host "[ERRO] Arquivo de candidatos invalido ou vazio." -ForegroundColor Red
    exit 1
}

$results = @()
$hasErrors = $false

foreach ($cat in $candidates.categories) {
    foreach ($item in $cat.items) {
        if ($item.manager -ne "winget") {
            continue
        }

        Write-Host "Validando: $($item.name) ..." -ForegroundColor Gray
        $ok = Test-WingetCandidateItem -PackageId $item.id
        $status = if ($ok) { "OK" } else { "ERRO" }

        $results += [PSCustomObject]@{
            Category = $cat.name
            Name = $item.name
            Id = $item.id
            Status = $status
        }

        if ($ok) {
            Write-Host "[OK]   $($cat.name) | $($item.name) | $($item.id)" -ForegroundColor Green
        } else {
            Write-Host "[ERRO] $($cat.name) | $($item.name) | $($item.id)" -ForegroundColor Red
            $hasErrors = $true
        }
    }
}

$reportPath = Export-WingetCandidatesValidationHtml -Results $results
Write-Host ""
Write-Host "Relatorio HTML: $reportPath" -ForegroundColor Cyan

$okCount = @($results | Where-Object { $_.Status -eq "OK" }).Count
$errCount = @($results | Where-Object { $_.Status -eq "ERRO" }).Count

Write-Host ""
Write-Host "Resumo: Total=$($results.Count) OK=$okCount ERRO=$errCount" -ForegroundColor Gray

if ($hasErrors) {
    Write-Host ""
    Write-Host "[FALHA] Existem candidatos invalidos no winget" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[SUCESSO] Todos os candidatos validados no winget" -ForegroundColor Green
exit 0
