function Invoke-QuickMachineTriage {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Diagnostico Rapido da Maquina" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    if (-not (Test-IsWindows)) {
        Write-Host ""
        Write-Host "Esta funcao e otimizada para Windows." -ForegroundColor DarkGray
        Write-Host "No Linux, exibindo informacoes disponiveis via PowerShell Core:"
        Write-Host ""
    }

    # --- Identificacao ---
    Write-Host "[ IDENTIFICACAO ]" -ForegroundColor Yellow
    Write-Host ("  Hostname    : {0}" -f [System.Net.Dns]::GetHostName())
    Write-Host ("  Sistema     : {0}" -f $PSVersionTable.OS)
    Write-Host ("  Arquitetura : {0}" -f [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)
    Write-Host ("  PowerShell  : {0}" -f $PSVersionTable.PSVersion)

    if (Test-IsWindows) {
        Write-Host ("  Usuario     : {0}" -f $env:USERNAME)
        try {
            $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            Write-Host ("  Dominio     : {0}" -f $(if ($cs.PartOfDomain) { $cs.Domain } else { "WORKGROUP: $($cs.Workgroup)" }))
        } catch { Write-Host "  Dominio     : N/A" }

        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            Write-Host ("  Windows     : {0} (Build {1})" -f $os.Caption, $os.BuildNumber)
        } catch {}
    } else {
        Write-Host ("  Usuario     : {0}" -f $env:USER)
        $kernel = & uname -r 2>$null
        if ($kernel) { Write-Host ("  Kernel      : {0}" -f $kernel) }
    }

    # --- Boot / Uptime ---
    Write-Host ""
    Write-Host "[ BOOT / UPTIME ]" -ForegroundColor Yellow
    if (Test-IsWindows) {
        try {
            $os     = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $uptime = (Get-Date) - $os.LastBootUpTime
            Write-Host ("  Ultimo boot : {0}" -f $os.LastBootUpTime.ToString('dd/MM/yyyy HH:mm:ss'))
            Write-Host ("  Uptime      : {0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
        } catch { Write-Host "  Indisponivel" }
    } else {
        $raw = Get-Content /proc/uptime -ErrorAction SilentlyContinue
        if ($raw) {
            $sec    = [double]($raw.Split(" ")[0])
            $bootDt = (Get-Date).AddSeconds(-$sec)
            $up     = New-TimeSpan -Seconds $sec
            Write-Host ("  Ultimo boot : {0}" -f $bootDt.ToString('dd/MM/yyyy HH:mm:ss'))
            Write-Host ("  Uptime      : {0}d {1}h {2}m" -f $up.Days, $up.Hours, $up.Minutes)
        }
    }

    # --- Rede ---
    Write-Host ""
    Write-Host "[ REDE ]" -ForegroundColor Yellow
    if (Test-IsWindows) {
        try {
            $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" }
            foreach ($ip in $ips) {
                Write-Host ("  IP          : {0}/{1} ({2})" -f $ip.IPAddress, $ip.PrefixLength, $ip.InterfaceAlias)
            }
            $gw = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($gw) { Write-Host ("  Gateway     : {0}" -f $gw.NextHop) }

            $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.ServerAddresses.Count -gt 0 } | Select-Object -First 1
            if ($dns) { Write-Host ("  DNS         : {0}" -f ($dns.ServerAddresses -join ", ")) }
        } catch { Write-Host "  Erro ao obter rede" }
    } else {
        $ipCmd = Get-Command ip -ErrorAction SilentlyContinue
        if ($ipCmd) {
            & ip -brief address 2>/dev/null | Where-Object { $_ -notmatch "^lo" } | ForEach-Object {
                Write-Host ("  {0}" -f $_.Trim())
            }
        }
    }

    # --- Disco C: / raiz ---
    Write-Host ""
    Write-Host "[ DISCO ]" -ForegroundColor Yellow
    if (Test-IsWindows) {
        try {
            $c = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
            $total = [math]::Round($c.Size / 1GB, 1)
            $free  = [math]::Round($c.FreeSpace / 1GB, 1)
            $used  = [math]::Round(($c.Size - $c.FreeSpace) / 1GB, 1)
            $pct   = [math]::Round(($c.Size - $c.FreeSpace) / $c.Size * 100, 1)
            Write-Host ("  C:  Total:{0}GB  Usado:{1}GB  Livre:{2}GB  ({3}%)" -f $total, $used, $free, $pct)
        } catch { Write-Host "  Erro ao obter disco" }
    } else {
        $dfCmd = Get-Command df -ErrorAction SilentlyContinue
        if ($dfCmd) {
            & df -h / 2>/dev/null | Select-Object -Skip 1 | ForEach-Object { Write-Host ("  {0}" -f $_.Trim()) }
        }
    }

    # --- Memoria ---
    Write-Host ""
    Write-Host "[ MEMORIA ]" -ForegroundColor Yellow
    if (Test-IsWindows) {
        try {
            $os      = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
            $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
            $usedGB  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
            Write-Host ("  Total: {0}GB  Usado: {1}GB  Livre: {2}GB" -f $totalGB, $usedGB, $freeGB)
        } catch { Write-Host "  Erro ao obter memoria" }
    } else {
        $memInfo = Get-Content /proc/meminfo -ErrorAction SilentlyContinue
        if ($memInfo) {
            $total = ($memInfo | Select-String "^MemTotal").ToString()  -replace "[^0-9]", ""
            $avail = ($memInfo | Select-String "^MemAvailable").ToString() -replace "[^0-9]", ""
            $totalGB = [math]::Round([long]$total / 1MB, 1)
            $availGB = [math]::Round([long]$avail / 1MB, 1)
            $usedGB  = [math]::Round($totalGB - $availGB, 1)
            Write-Host ("  Total: {0}GB  Usado: ~{1}GB  Livre: ~{2}GB" -f $totalGB, $usedGB, $availGB)
        }
    }

    # --- Top processos ---
    Write-Host ""
    Write-Host "[ TOP 5 PROCESSOS - MEMORIA ]" -ForegroundColor Yellow
    try {
        Get-Process -ErrorAction Stop |
            Sort-Object WorkingSet64 -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                Write-Host ("  {0,-25} Mem:{1,6}MB  PID:{2}" -f `
                    $_.ProcessName.Substring(0, [Math]::Min(25, $_.ProcessName.Length)),
                    [math]::Round($_.WorkingSet64 / 1MB, 0), $_.Id)
            }
    } catch { Write-Host "  Erro ao obter processos" }

    Write-Host ""
    Write-Host "[ TOP 5 PROCESSOS - CPU ]" -ForegroundColor Yellow
    try {
        Get-Process -ErrorAction Stop |
            Where-Object { $_.CPU -ne $null } |
            Sort-Object CPU -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                Write-Host ("  {0,-25} CPU:{1,8}s  PID:{2}" -f `
                    $_.ProcessName.Substring(0, [Math]::Min(25, $_.ProcessName.Length)),
                    [math]::Round($_.CPU, 1), $_.Id)
            }
    } catch { Write-Host "  Erro ao obter processos" }

    Write-Host ""
    Write-Log -Message "Invoke-QuickMachineTriage executado" -Level "INFO"
}
