# ==========================================
# Atlas - Modulo de Historico Operacional
# ==========================================

function Get-AtlasRecentLogs {
    param(
        [int]$Count = 50
    )

    $logPath = Get-AtlasLogPath
    if (-not (Test-Path $logPath)) {
        return @()
    }

    $lines = Get-Content -Path $logPath -ErrorAction SilentlyContinue
    if (-not $lines) {
        return @()
    }

    if ($lines.Count -le $Count) {
        return @($lines)
    }

    return @($lines | Select-Object -Last $Count)
}

function Open-AtlasLogFolder {
    $logPath = Get-AtlasLogPath
    $folder = Split-Path $logPath -Parent

    if (-not (Test-Path $folder)) {
        Initialize-AtlasLogger | Out-Null
        $folder = Split-Path (Get-AtlasLogPath) -Parent
    }

    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        Start-Process explorer.exe $folder
    } else {
        Write-Host "Pasta de logs: $folder" -ForegroundColor Cyan
    }
}

function Clear-AtlasLogs {
    Write-Host ""
    Write-Host "Esta acao apagara todo o historico operacional." -ForegroundColor Yellow
    Write-Host "Tem certeza? [S/N]: " -NoNewline
    $resp = Read-Host

    if ($resp -notmatch '^[sS]$') {
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    $logPath = Get-AtlasLogPath
    $folder = Split-Path $logPath -Parent

    if (-not (Test-Path $folder)) {
        Initialize-AtlasLogger | Out-Null
        $logPath = Get-AtlasLogPath
    }

    try {
        Set-Content -Path $logPath -Value "" -Encoding UTF8
        Write-AtlasLog -Nivel INFO -Modulo "Sistema" -Acao "Limpeza de Logs" -Resultado "Sucesso"
        Write-Host "Historico limpo com sucesso." -ForegroundColor Green
    } catch {
        Write-Host "Erro ao limpar historico: $_" -ForegroundColor Red
    }
}

function Show-HistoryMenu {
    $historyRunning = $true

    while ($historyRunning) {
        Show-AtlasHeader -Title "Historico"

        Show-AtlasCompactOption -Number "1" -Name "Ultimos 50 eventos"
        Show-AtlasCompactOption -Number "2" -Name "Abrir pasta de logs"
        Show-AtlasCompactOption -Number "3" -Name "Limpar logs"

        Show-AtlasBackOption
        $option = Read-AtlasMenuChoice

        switch ($option) {
            "1" {
                Write-Host ""
                Write-Host "Ultimos 50 eventos:" -ForegroundColor Cyan
                Write-Host ""
                $events = Get-AtlasRecentLogs -Count 50
                if ($events.Count -eq 0) {
                    Write-AtlasInfo "Nenhum evento registrado."
                } else {
                    foreach ($line in $events) {
                        Write-Host $line -ForegroundColor White
                    }
                }
                Wait-UserInput
            }
            "2" {
                Open-AtlasLogFolder
                Wait-UserInput
            }
            "3" {
                Clear-AtlasLogs
                Wait-UserInput
            }
            "0" {
                $historyRunning = $false
            }
            default {
                Write-AtlasWarning "Opcao invalida."
                Wait-UserInput
            }
        }
    }
}
