function Get-RecentErrorEvents {

    Write-Host ""
    Write-Host "Eventos recentes de erro (ultimos 2 dias):" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Host "No Linux, use 'journalctl -p err' para ver erros do sistema."
        Write-Log -Message "Get-RecentErrorEvents chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    try {
        $since  = (Get-Date).AddDays(-2)
        $events = Get-WinEvent -FilterHashtable @{
            Level     = 2   # Error
            StartTime = $since
        } -MaxEvents 20 -ErrorAction Stop

        if ($events.Count -eq 0) {
            Write-Host "Nenhum evento de erro encontrado nos ultimos 2 dias." -ForegroundColor Green
        }
        else {
            $events | ForEach-Object {
                [PSCustomObject]@{
                    Hora       = $_.TimeCreated.ToString("dd/MM HH:mm")
                    Fonte      = $_.ProviderName
                    EventoId   = $_.Id
                    Mensagem   = ($_.Message -replace "`n", " ").Substring(0, [Math]::Min(80, $_.Message.Length))
                }
            } | Format-Table Hora, Fonte, EventoId, Mensagem -AutoSize -Wrap
        }

        Write-Log -Message "Get-RecentErrorEvents executado. Eventos encontrados: $($events.Count)" -Level "INFO"
    }
    catch [System.Exception] {
        if ($_.Exception.Message -match "No events were found") {
            Write-Host "Nenhum evento de erro encontrado nos ultimos 2 dias." -ForegroundColor Green
            Write-Log -Message "Get-RecentErrorEvents: nenhum evento de erro" -Level "INFO"
        }
        else {
            Write-Host "Erro ao consultar eventos: $_" -ForegroundColor Red
            Write-Log -Message "Erro em Get-RecentErrorEvents: $_" -Level "ERROR"
        }
    }
}
