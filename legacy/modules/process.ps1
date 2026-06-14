function Get-TopCpuProcesses {

    Write-Host ""
    Write-Host "Top 10 processos por CPU:" -ForegroundColor Yellow
    Write-Host ""

    try {
        $processes = Get-Process -ErrorAction Stop |
            Where-Object { $_.CPU -ne $null } |
            Sort-Object CPU -Descending |
            Select-Object -First 10

        if ($processes) {
            $processes | ForEach-Object {
                [PSCustomObject]@{
                    Nome   = $_.ProcessName.Substring(0, [Math]::Min(28, $_.ProcessName.Length))
                    PID    = $_.Id
                    CPU_s  = [math]::Round($_.CPU, 2)
                    Mem_MB = [math]::Round($_.WorkingSet64 / 1MB, 1)
                }
            } | Format-Table Nome, PID, CPU_s, Mem_MB -AutoSize
        }
        else {
            Write-Host "Nenhum processo retornado." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "Erro ao obter processos: $_" -ForegroundColor Red
    }

    Write-Log -Message "Get-TopCpuProcesses executado" -Level "INFO"
}

function Get-TopMemoryProcesses {

    Write-Host ""
    Write-Host "Top 10 processos por uso de memoria:" -ForegroundColor Yellow
    Write-Host ""

    try {
        $processes = Get-Process -ErrorAction Stop |
            Sort-Object WorkingSet64 -Descending |
            Select-Object -First 10

        if ($processes) {
            $processes | ForEach-Object {
                $cpuVal = if ($_.CPU) { [math]::Round($_.CPU, 2) } else { 0 }
                [PSCustomObject]@{
                    Nome   = $_.ProcessName.Substring(0, [Math]::Min(28, $_.ProcessName.Length))
                    PID    = $_.Id
                    Mem_MB = [math]::Round($_.WorkingSet64 / 1MB, 1)
                    CPU_s  = $cpuVal
                }
            } | Format-Table Nome, PID, Mem_MB, CPU_s -AutoSize
        }
        else {
            Write-Host "Nenhum processo retornado." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "Erro ao obter processos: $_" -ForegroundColor Red
    }

    Write-Log -Message "Get-TopMemoryProcesses executado" -Level "INFO"
}
