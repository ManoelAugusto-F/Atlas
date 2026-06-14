function New-AtlasTxtReport {

    Write-Host ""
    Write-Host "Gerando relatorio Atlas..." -ForegroundColor Yellow
    Write-Host ""

    $reportsDir = Join-Path $PSScriptRoot "../reports"
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }

    $timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportPath = Join-Path $reportsDir "atlas_report_$timestamp.txt"

    $lines = [System.Collections.Generic.List[string]]::new()

    $sep = "=" * 50

    # Cabecalho
    $lines.Add($sep)
    $lines.Add(" ATLAS - Relatorio de Diagnostico")
    $lines.Add(" Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')")
    $lines.Add($sep)
    $lines.Add("")

    # 1. Informacoes do sistema
    $lines.Add("[ SISTEMA ]")
    $lines.Add("Hostname    : $([System.Net.Dns]::GetHostName())")
    $lines.Add("Sistema     : $($PSVersionTable.OS)")
    $lines.Add("Arquitetura : $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)")
    $lines.Add("PowerShell  : $($PSVersionTable.PSVersion)")
    if (Test-IsWindows) {
        $lines.Add("Usuario     : $env:USERNAME")
    } else {
        $lines.Add("Usuario     : $env:USER")
        $kernel = & uname -r 2>$null
        if ($kernel) { $lines.Add("Kernel      : $kernel") }
    }
    $lines.Add("")

    # 2. Ultimo boot
    $lines.Add("[ ULTIMO BOOT ]")
    if (Test-IsWindows) {
        try {
            $os     = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $uptime = (Get-Date) - $os.LastBootUpTime
            $lines.Add("Boot   : $($os.LastBootUpTime.ToString('dd/MM/yyyy HH:mm:ss'))")
            $lines.Add(("Uptime : {0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes))
        } catch { $lines.Add("Indisponivel") }
    } else {
        $procUptime = Get-Content /proc/uptime -ErrorAction SilentlyContinue
        if ($procUptime) {
            $seconds = [double]($procUptime.Split(" ")[0])
            $bootDt  = (Get-Date).AddSeconds(-$seconds)
            $uptime  = New-TimeSpan -Seconds $seconds
            $lines.Add("Boot   : $($bootDt.ToString('dd/MM/yyyy HH:mm:ss'))")
            $lines.Add(("Uptime : {0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes))
        } else { $lines.Add("Indisponivel") }
    }
    $lines.Add("")

    # 3. Rede
    $lines.Add("[ REDE ]")
    if (Test-IsWindows) {
        try {
            $adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.IPAddress -ne "127.0.0.1" }
            foreach ($a in $adapters) {
                $lines.Add("$($a.InterfaceAlias) : $($a.IPAddress)/$($a.PrefixLength)")
            }
        } catch { $lines.Add("Erro ao obter rede") }
    } else {
        $ipCmd = Get-Command ip -ErrorAction SilentlyContinue
        if ($ipCmd) {
            $ipOut = & ip -brief address 2>/dev/null
            foreach ($l in $ipOut) { $lines.Add($l) }
        } else { $lines.Add("Comando 'ip' nao disponivel") }
    }
    $lines.Add("")

    # 4. Disco
    $lines.Add("[ DISCO ]")
    if (Test-IsWindows) {
        try {
            $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
            foreach ($d in $disks) {
                $total = [math]::Round($d.Size / 1GB, 1)
                $free  = [math]::Round($d.FreeSpace / 1GB, 1)
                $used  = [math]::Round(($d.Size - $d.FreeSpace) / 1GB, 1)
                $lines.Add(("{0}  Total: {1}GB  Usado: {2}GB  Livre: {3}GB" -f $d.DeviceID, $total, $used, $free))
            }
        } catch { $lines.Add("Erro ao obter disco") }
    } else {
        $dfCmd = Get-Command df -ErrorAction SilentlyContinue
        if ($dfCmd) {
            $dfOut = & df -h 2>/dev/null | Select-String "^/"
            foreach ($l in $dfOut) { $lines.Add($l.Line.Trim()) }
        } else { $lines.Add("Comando 'df' nao disponivel") }
    }
    $lines.Add("")

    # 5. Top CPU
    $lines.Add("[ TOP 10 CPU ]")
    try {
        $procs = Get-Process -ErrorAction Stop |
            Where-Object { $_.CPU -ne $null } |
            Sort-Object CPU -Descending |
            Select-Object -First 10
        foreach ($p in $procs) {
            $lines.Add(("{0,-30} PID:{1,-7} CPU:{2,8}s  Mem:{3,7}MB" -f `
                $p.ProcessName, $p.Id, [math]::Round($p.CPU,1), [math]::Round($p.WorkingSet64/1MB,1)))
        }
    } catch { $lines.Add("Erro ao obter processos") }
    $lines.Add("")

    # 6. Top Memoria
    $lines.Add("[ TOP 10 MEMORIA ]")
    try {
        $procs = Get-Process -ErrorAction Stop |
            Sort-Object WorkingSet64 -Descending |
            Select-Object -First 10
        foreach ($p in $procs) {
            $cpuVal = if ($p.CPU) { [math]::Round($p.CPU,1) } else { 0 }
            $lines.Add(("{0,-30} PID:{1,-7} Mem:{2,7}MB  CPU:{3,8}s" -f `
                $p.ProcessName, $p.Id, [math]::Round($p.WorkingSet64/1MB,1), $cpuVal))
        }
    } catch { $lines.Add("Erro ao obter processos") }
    $lines.Add("")

    $lines.Add($sep)
    $lines.Add(" Fim do relatorio")
    $lines.Add($sep)

    # Gravar arquivo
    try {
        $lines | Set-Content -Path $reportPath -Encoding UTF8 -ErrorAction Stop
        Write-Host "Relatorio gerado com sucesso:" -ForegroundColor Green
        Write-Host "  $reportPath" -ForegroundColor Cyan
        Write-Log -Message "Relatorio gerado: $reportPath" -Level "INFO"
    }
    catch {
        Write-Host "Erro ao gravar relatorio: $_" -ForegroundColor Red
        Write-Log -Message "Erro ao gravar relatorio: $_" -Level "ERROR"
    }
}
