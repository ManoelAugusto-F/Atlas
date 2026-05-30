function Clear-UserTempFiles {

    Write-Host ""
    Write-Host "Limpeza de arquivos temporarios:" -ForegroundColor Yellow
    Write-Host ""

    if (Test-IsWindows) {
        $tempPath = $env:TEMP

        if (-not $tempPath -or -not (Test-Path $tempPath)) {
            Write-Host "Caminho de temporarios nao encontrado." -ForegroundColor Red
            return
        }

        Write-Host "Caminho que sera limpo: $tempPath"
        Write-Host ""

        $files = Get-ChildItem -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        $total = $files.Count

        Write-Host "Arquivos encontrados: $total"
        Write-Log -Message "Iniciando limpeza de temporarios em: $tempPath ($total itens)" -Level "INFO"

        $removed = 0
        $errors  = 0

        foreach ($item in $files) {
            try {
                Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction Stop
                $removed++
            }
            catch {
                $errors++
            }
        }

        Write-Host "Removidos : $removed" -ForegroundColor Green
        if ($errors -gt 0) {
            Write-Host "Em uso (ignorados): $errors" -ForegroundColor DarkGray
        }

        Write-Log -Message "Limpeza concluida. Removidos: $removed, Ignorados: $errors" -Level "INFO"
    }
    else {
        Write-Host "Esta funcao realiza limpeza real apenas no Windows." -ForegroundColor DarkGray
        Write-Host "No Linux, os arquivos temporarios ficam em /tmp e sao gerenciados pelo sistema."
        Write-Log -Message "Clear-UserTempFiles chamado no Linux (sem acao)" -Level "INFO"
    }
}

function Get-StoppedImportantServices {

    Write-Host ""
    Write-Host "Servicos importantes parados:" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Host "No Linux, use 'systemctl status' para verificar servicos."
        Write-Log -Message "Get-StoppedImportantServices chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    $important = @("WinRM", "wuauserv", "Spooler", "EventLog", "BITS")
    $stopped   = @()

    foreach ($svcName in $important) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            $status = $svc.Status
            $color  = if ($status -eq "Running") { "Green" } else { "Red" }
            Write-Host ("  {0,-20} {1}" -f $svcName, $status) -ForegroundColor $color
            if ($status -ne "Running") { $stopped += $svcName }
        }
        else {
            Write-Host ("  {0,-20} {1}" -f $svcName, "NAO ENCONTRADO") -ForegroundColor DarkGray
        }
    }

    if ($stopped.Count -eq 0) {
        Write-Host ""
        Write-Host "Todos os servicos importantes estao em execucao." -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "Servicos parados: $($stopped -join ', ')" -ForegroundColor Yellow
    }

    Write-Log -Message "Verificacao de servicos concluida. Parados: $($stopped.Count)" -Level "INFO"
}
