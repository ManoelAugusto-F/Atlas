function Get-DiskUsage {

    Write-Host ""
    Write-Host "Uso de disco:" -ForegroundColor Yellow
    Write-Host ""

    if (Test-IsWindows) {
        try {
            $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
            foreach ($disk in $disks) {
                $totalGB = [math]::Round($disk.Size / 1GB, 2)
                $freeGB  = [math]::Round($disk.FreeSpace / 1GB, 2)
                $usedGB  = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
                $pct     = if ($disk.Size -gt 0) { [math]::Round(($disk.Size - $disk.FreeSpace) / $disk.Size * 100, 1) } else { 0 }

                Write-Host ("  {0,-5}  Usado: {1,7} GB  Livre: {2,7} GB  Total: {3,7} GB  ({4}%)" -f `
                    $disk.DeviceID, $usedGB, $freeGB, $totalGB, $pct)
            }
        }
        catch {
            Write-Host "Erro ao obter informacoes de disco: $_" -ForegroundColor Red
        }
    }
    else {
        # Linux — usar Get-PSDrive para drives PS ou df para disco real
        $dfCmd = Get-Command df -ErrorAction SilentlyContinue
        if ($dfCmd) {
            Write-Host "Partições (df -h):"
            $dfOutput = & df -h 2>/dev/null | Select-String -Pattern "^/" 
            foreach ($line in $dfOutput) {
                Write-Host "  $($line.Line)"
            }
        }
        else {
            Write-Host "Drives PowerShell (Get-PSDrive):"
            Get-PSDrive -PSProvider FileSystem | ForEach-Object {
                $usedGB  = if ($_.Used)  { [math]::Round($_.Used  / 1GB, 2) } else { "N/A" }
                $freeGB  = if ($_.Free)  { [math]::Round($_.Free  / 1GB, 2) } else { "N/A" }
                Write-Host ("  {0,-10}  Usado: {1,7} GB  Livre: {2,7} GB" -f $_.Name, $usedGB, $freeGB)
            }
        }
    }

    Write-Log -Message "Get-DiskUsage executado" -Level "INFO"
    Write-Host ""
}

function Get-LastBootTime {

    Write-Host ""
    Write-Host "Ultimo boot do sistema:" -ForegroundColor Yellow
    Write-Host ""

    if (Test-IsWindows) {
        try {
            $os       = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            $bootTime = $os.LastBootUpTime
            $uptime   = (Get-Date) - $bootTime

            Write-Host "  Ultimo boot : $($bootTime.ToString('dd/MM/yyyy HH:mm:ss'))"
            Write-Host ("  Uptime      : {0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
        }
        catch {
            Write-Host "Erro ao obter data de boot: $_" -ForegroundColor Red
        }
    }
    else {
        $uptimeCmd = Get-Command uptime -ErrorAction SilentlyContinue
        if ($uptimeCmd) {
            $result = & uptime -s 2>/dev/null
            if ($result) {
                Write-Host "  Ultimo boot : $result"
                $bootDt = [datetime]::Parse($result)
                $uptime = (Get-Date) - $bootDt
                Write-Host ("  Uptime      : {0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
            }
            else {
                $result = & uptime 2>/dev/null
                Write-Host "  $result"
            }
        }
        else {
            $procUptime = Get-Content /proc/uptime -ErrorAction SilentlyContinue
            if ($procUptime) {
                $seconds    = [double]($procUptime.Split(" ")[0])
                $bootDt     = (Get-Date).AddSeconds(-$seconds)
                $uptime     = New-TimeSpan -Seconds $seconds
                Write-Host "  Ultimo boot : $($bootDt.ToString('dd/MM/yyyy HH:mm:ss'))"
                Write-Host ("  Uptime      : {0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
            }
            else {
                Write-Host "  Informacao de boot indisponivel neste sistema." -ForegroundColor DarkGray
            }
        }
    }

    Write-Log -Message "Get-LastBootTime executado" -Level "INFO"
    Write-Host ""
}
