# ==========================================
# Atlas - Modulo de Relatorio de Suporte
# ==========================================

# Captura o diretorio do modulo no momento do carregamento (dot-source)
$script:_SupportModuleDir = $PSScriptRoot

# ------------------------------------------
# Helpers internos
# ------------------------------------------

function script:Test-IsWindowsSupportReport {
    return ($IsWindows -or $env:OS -eq 'Windows_NT')
}

function script:Build-SystemSection {
    $lines = @()
    $lines += "Hostname      : $([System.Environment]::MachineName)"
    $lines += "Usuario       : $([System.Environment]::UserName)"
    $lines += "Data/Hora     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "Processadores : $([System.Environment]::ProcessorCount)"
    $lines += "Plataforma    : $([System.Environment]::OSVersion.Platform)"
    $lines += "Versao OS     : $([System.Environment]::OSVersion.VersionString)"

    if (script:Test-IsWindowsSupportReport) {
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $lines += "Nome OS       : $($os.Caption)"
            $lines += "Build         : $($os.BuildNumber)"
            $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            $freeGB  = [math]::Round($os.FreePhysicalMemory  / 1MB, 2)
            $usedGB  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
            $lines += "RAM Total     : ${totalGB} GB"
            $lines += "RAM Livre     : ${freeGB} GB"
            $lines += "RAM Em Uso    : ${usedGB} GB"
            $up = (Get-Date) - $os.LastBootUpTime
            $lines += "Uptime        : $([int]$up.TotalDays)d $($up.Hours)h $($up.Minutes)m"
        } catch {
            $lines += "[AVISO] Dados WMI indisponiveis: $_"
        }
    } else {
        try {
            $uptimeOut = & uptime 2>&1
            $lines += "Uptime        : $uptimeOut"
        } catch { }
        if (Test-Path /proc/meminfo) {
            Get-Content /proc/meminfo |
                Where-Object { $_ -match '^MemTotal:|^MemAvailable:' } |
                ForEach-Object { $lines += "Memoria       : $_" }
        }
    }

    return $lines -join "`n"
}

function script:Build-DiskSection {
    $lines = @()

    if (script:Test-IsWindowsSupportReport) {
        try {
            $drives = Get-PSDrive -PSProvider FileSystem -ErrorAction Stop
            foreach ($d in $drives) {
                $cap = $d.Used + $d.Free
                if ($null -ne $d.Used -and $cap -gt 0) {
                    $totalGB = [math]::Round($cap / 1GB, 2)
                    $usedGB  = [math]::Round($d.Used / 1GB, 2)
                    $freeGB  = [math]::Round($d.Free / 1GB, 2)
                    $pct     = [math]::Round($d.Used / $cap * 100, 1)
                    $lines += "$($d.Name):\ | Total: ${totalGB}GB | Usado: ${usedGB}GB | Livre: ${freeGB}GB | ${pct}%"
                }
            }
        } catch {
            $lines += "[AVISO] Erro ao coletar informacoes de disco: $_"
        }
    } else {
        try {
            (& df -h 2>&1) | ForEach-Object { $lines += $_ }
        } catch {
            $lines += "[AVISO] Erro ao executar df: $_"
        }
    }

    return $lines -join "`n"
}

function script:Build-NetworkSection {
    $lines = @()

    $lines += "--- Teste de Conectividade ---"
    try {
        $addrs = [System.Net.Dns]::GetHostAddresses("google.com")
        $lines += "[OK]    DNS google.com -> $($addrs[0].IPAddressToString)"
    } catch {
        $lines += "[FALHA] DNS google.com: $_"
    }
    try {
        $tcp  = New-Object System.Net.Sockets.TcpClient
        $conn = $tcp.BeginConnect("google.com", 443, $null, $null)
        $ok   = $conn.AsyncWaitHandle.WaitOne(3000, $false)
        if ($ok -and $tcp.Connected) {
            $lines += "[OK]    TCP 443 -> google.com"
        } else {
            $lines += "[FALHA] TCP 443 -> google.com (timeout)"
        }
        $tcp.Close()
    } catch {
        $lines += "[FALHA] TCP 443 -> google.com: $_"
    }

    $lines += ""
    $lines += "--- Configuracao de Rede ---"

    if (script:Test-IsWindowsSupportReport) {
        try {
            $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' }
            foreach ($a in $adapters) {
                $lines += "Interface: $($a.Name) | $($a.InterfaceDescription)"
                try {
                    $ip = Get-NetIPAddress -InterfaceIndex $a.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
                    if ($ip) { $lines += "  IPv4: $($ip.IPAddress)/$($ip.PrefixLength)" }
                } catch { }
            }
        } catch {
            try {
                (& ipconfig 2>&1) | ForEach-Object { $lines += $_ }
            } catch {
                $lines += "[AVISO] Nao foi possivel coletar configuracao de rede"
            }
        }
        try {
            $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.ServerAddresses.Count -gt 0 }
            $lines += "DNS configurado:"
            $dnsServers | ForEach-Object { $lines += "  $($_.InterfaceAlias): $($_.ServerAddresses -join ', ')" }
        } catch { }
    } else {
        try {
            (& ip addr 2>&1)   | ForEach-Object { $lines += $_ }
            $lines += ""
            $lines += "--- Rotas ---"
            (& ip route 2>&1)  | ForEach-Object { $lines += $_ }
            if (Test-Path /etc/resolv.conf) {
                $lines += ""
                $lines += "--- DNS (/etc/resolv.conf) ---"
                Get-Content /etc/resolv.conf | ForEach-Object { $lines += $_ }
            }
        } catch {
            $lines += "[AVISO] Erro ao coletar configuracao de rede: $_"
        }
    }

    return $lines -join "`n"
}

function script:Build-OneDriveSection {
    $lines = @()

    if (-not (script:Test-IsWindowsSupportReport)) {
        $lines += "OneDrive disponivel apenas no Windows."
        return ($lines -join "`n")
    }

    $proc = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    $lines += "Processo  : $(if ($proc) { "Em execucao (PID $($proc.Id))" } else { "Parado" })"

    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
        "C:\Program Files\Microsoft OneDrive\OneDrive.exe",
        "C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe"
    )
    $exe = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
    $lines += "Executavel: $(if ($exe) { $exe } else { "Nao encontrado" })"

    $folder = if ($env:OneDrive) { $env:OneDrive } elseif ($env:OneDriveConsumer) { $env:OneDriveConsumer } else { $null }
    if ($folder) {
        $lines += "Pasta     : $folder"
        $lines += "Existe    : $(Test-Path $folder)"
    } else {
        $lines += "Pasta     : Variavel de ambiente nao definida"
    }

    return $lines -join "`n"
}

function script:Build-PrinterSection {
    $lines = @()

    if (-not (script:Test-IsWindowsSupportReport)) {
        $lines += "Impressoras disponiveis apenas no Windows."
        return ($lines -join "`n")
    }

    try {
        $spooler = Get-Service -Name Spooler -ErrorAction Stop
        $lines += "Servico Spooler: $($spooler.Status)"
    } catch {
        $lines += "Servico Spooler: Nao disponivel ($_)"
    }

    $lines += ""
    try {
        if (Get-Module -ListAvailable -Name PrintManagement -ErrorAction SilentlyContinue) {
            Import-Module PrintManagement -ErrorAction SilentlyContinue
        }
        $printers = Get-Printer -ErrorAction Stop
        $lines += "Impressoras ($($printers.Count)):"
        foreach ($p in $printers) {
            $def = if ($p.Default) { " [PADRAO]" } else { "" }
            $lines += "  $($p.Name)$def | Status: $($p.PrinterStatus) | Compartilhada: $($p.Shared)"
        }
    } catch {
        $lines += "[AVISO] Nao foi possivel listar impressoras: $_"
    }

    return $lines -join "`n"
}

function script:Build-QuickDiagnosticSection {
    $lines = @()
    $lines += "Data/Hora : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "Host      : $([System.Environment]::MachineName)"
    $lines += "Usuario   : $([System.Environment]::UserName)"
    $lines += "OS        : $([System.Environment]::OSVersion.VersionString)"
    $lines += ""

    $lines += "--- Conectividade ---"
    try {
        [System.Net.Dns]::GetHostAddresses("google.com") | Out-Null
        $lines += "[OK]    Internet acessivel"
    } catch {
        $lines += "[FALHA] Sem acesso a internet"
    }

    $lines += ""
    $lines += "--- Disco ---"
    if (script:Test-IsWindowsSupportReport) {
        try {
            Get-PSDrive -PSProvider FileSystem |
                Where-Object { $null -ne $_.Used -and ($_.Used + $_.Free) -gt 0 } |
                ForEach-Object {
                    $freeGB  = [math]::Round($_.Free / 1GB, 2)
                    $totalGB = [math]::Round(($_.Used + $_.Free) / 1GB, 2)
                    $pct     = [math]::Round($_.Used / ($_.Used + $_.Free) * 100, 1)
                    $lines += "$($_.Name):\ | Livre: ${freeGB}GB / ${totalGB}GB | ${pct}% usado"
                }
        } catch { $lines += "[AVISO] Erro ao verificar disco" }
    } else {
        try {
            (& df -h / 2>&1) | ForEach-Object { $lines += $_ }
        } catch { $lines += "[AVISO] Erro ao verificar disco" }
    }

    $lines += ""
    $lines += "--- Memoria ---"
    if (script:Test-IsWindowsSupportReport) {
        try {
            $os      = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
            $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            $lines += "RAM: Livre ${freeGB}GB / Total ${totalGB}GB"
        } catch { $lines += "[AVISO] Erro ao verificar memoria" }
    } else {
        if (Test-Path /proc/meminfo) {
            try {
                $rawTotal = (Get-Content /proc/meminfo | Where-Object { $_ -match '^MemTotal:' })     -replace '[^\d]', ''
                $rawFree  = (Get-Content /proc/meminfo | Where-Object { $_ -match '^MemAvailable:' }) -replace '[^\d]', ''
                $totalGB  = [math]::Round([long]$rawTotal / 1MB, 2)
                $freeGB   = [math]::Round([long]$rawFree  / 1MB, 2)
                $lines += "RAM: Livre ${freeGB}GB / Total ${totalGB}GB"
            } catch { $lines += "[AVISO] Erro ao ler /proc/meminfo" }
        }
    }

    return $lines -join "`n"
}

# Helper: coleta uma secao, escreve no arquivo, retorna status
function script:Invoke-SupportSection {
    param(
        [string]$FilePath,
        [string]$Title,
        [scriptblock]$Collector
    )
    Write-Host "  Coletando: $Title..." -ForegroundColor Gray
    Write-Log -Message "Coletando secao: $Title" -Level "INFO"
    try {
        $body   = & $Collector
        $header = "Atlas - Relatorio de Suporte`n$Title`nGerado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nHost: $([System.Environment]::MachineName)`n$('=' * 50)`n"
        Set-Content -Path $FilePath -Value ($header + "`n" + $body) -Encoding UTF8
        return "ok"
    } catch {
        $errMsg = "ERRO ao coletar '$Title': $_"
        Write-Log -Message $errMsg -Level "WARN"
        Set-Content -Path $FilePath -Value $errMsg -Encoding UTF8
        return "error"
    }
}


# ------------------------------------------
# Relatorio HTML v0.2.2 - coleta e render
# ------------------------------------------

function script:Escape-HtmlText {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return ($Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}

function script:Get-StatusCssSuffix {
    param([string]$Status)
    switch ($Status) {
        "OK"      { return "ok" }
        "ATENCAO" { return "atencao" }
        "CRITICO" { return "critico" }
        default   { return "na" }
    }
}

function script:Get-OverallStatusFromAlerts {
    param([array]$Alerts)
    $overall = "OK"
    foreach ($a in $Alerts) {
        if ($a.Status -eq "CRITICO") { return "CRITICO" }
        if ($a.Status -eq "ATENCAO" -and $overall -eq "OK") { $overall = "ATENCAO" }
    }
    return $overall
}

function script:Get-ReportAlertSafe {
    param([string]$FunctionName)
    try {
        if (Get-Command $FunctionName -ErrorAction SilentlyContinue) {
            return & $FunctionName
        }
    } catch { }
    return $null
}

function script:Collect-RdpReportData {
    $data = @{
        Status = "NA"
        TermService = "N/A"
        Port3389 = "N/A"
        Firewall = "N/A"
        Detail = "N/A"
        Lines = @()
    }
    if (-not (script:Test-IsWindowsSupportReport)) {
        $data.Detail = "RDP disponivel apenas no Windows"
        return $data
    }
    try {
        $svc = Get-Service -Name TermService -ErrorAction Stop
        $data.TermService = "$($svc.Status) ($($svc.StartType))"
        $data.Lines += "TermService: $($data.TermService)"
    } catch {
        $data.TermService = "N/A ($_)"
        $data.Lines += "TermService: $($data.TermService)"
    }
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $conn = $tcp.BeginConnect("127.0.0.1", 3389, $null, $null)
        $ok = $conn.AsyncWaitHandle.WaitOne(2000, $false)
        if ($ok -and $tcp.Connected) {
            $data.Port3389 = "Aberta (escutando)"
            $tcp.Close()
        } else {
            $data.Port3389 = "Fechada ou sem resposta"
            $tcp.Close()
        }
        $data.Lines += "Porta 3389: $($data.Port3389)"
    } catch {
        $data.Port3389 = "N/A"
        $data.Lines += "Porta 3389: N/A"
    }
    try {
        $fwRules = Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue |
            Select-Object -First 3 DisplayName, Enabled, Direction
        if ($fwRules) {
            $data.Firewall = ($fwRules | ForEach-Object { "$($_.DisplayName)=$($_.Enabled)" }) -join "; "
        } else {
            $data.Firewall = "Regras nao listadas"
        }
        $data.Lines += "Firewall RDP: $($data.Firewall)"
    } catch {
        $data.Firewall = "N/A"
        $data.Lines += "Firewall RDP: N/A"
    }
    if ($data.TermService -like "Running*") {
        $data.Status = "OK"
        $data.Detail = "Servico RDP ativo"
    } elseif ($data.TermService -ne "N/A") {
        $data.Status = "ATENCAO"
        $data.Detail = "Servico RDP nao esta em execucao"
    }
    return $data
}

function script:Collect-NetworkReportData {
    $lines = @()
    $dnsOk = $false
    $tcpOk = $false
    $pingOk = $false
    $primaryIp = "N/A"
    $gateway = "N/A"
    $dnsConfig = "N/A"

    try {
        $addrs = [System.Net.Dns]::GetHostAddresses("google.com")
        $dnsOk = $true
        $lines += "[OK] DNS google.com -> $($addrs[0].IPAddressToString)"
    } catch {
        $lines += "[FALHA] DNS google.com: $_"
    }

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $conn = $tcp.BeginConnect("google.com", 443, $null, $null)
        $wait = $conn.AsyncWaitHandle.WaitOne(3000, $false)
        if ($wait -and $tcp.Connected) { $tcpOk = $true; $lines += "[OK] TCP 443 google.com" } else { $lines += "[FALHA] TCP 443 timeout" }
        $tcp.Close()
    } catch {
        $lines += "[FALHA] TCP 443: $_"
    }

    if (script:Test-IsWindowsSupportReport) {
        try {
            $ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
            $pingOk = [bool]$ping
            $lines += $(if ($pingOk) { "[OK] Ping 8.8.8.8" } else { "[FALHA] Ping 8.8.8.8" })
        } catch {
            $lines += "[FALHA] Ping 8.8.8.8: $_"
        }
        try {
            $route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop | Select-Object -First 1
            if ($route) {
                $gwAddr = (Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
                $gateway = if ($gwAddr) { $route.NextHop } else { $route.NextHop }
            }
        } catch { }
        try {
            $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.IPAddress -notlike "127.*" -and $_.PrefixOrigin -ne "WellKnown" } |
                Select-Object -First 1
            if ($ip) { $primaryIp = "$($ip.IPAddress)/$($ip.PrefixLength)" }
        } catch { }
        try {
            $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.ServerAddresses.Count -gt 0 } |
                Select-Object -First 1
            if ($dnsServers) { $dnsConfig = $dnsServers.ServerAddresses -join ", " }
        } catch { }
    } else {
        try {
            $pingOut = & ping -c 1 -W 2 8.8.8.8 2>&1
            $pingOk = ($LASTEXITCODE -eq 0)
            $lines += $(if ($pingOk) { "[OK] Ping 8.8.8.8" } else { "[FALHA] Ping 8.8.8.8" })
        } catch { $lines += "[FALHA] Ping 8.8.8.8" }
    }

    $status = if ($dnsOk -and $tcpOk) { "OK" } elseif ($dnsOk -or $tcpOk) { "ATENCAO" } else { "CRITICO" }

    return @{
        Status = $status
        PrimaryIp = $primaryIp
        Gateway = $gateway
        DnsConfig = $dnsConfig
        DnsOk = $dnsOk
        TcpOk = $tcpOk
        PingOk = $pingOk
        Lines = $lines
    }
}

function script:Collect-SlownessReportData {
    $memText = "N/A"
    $diskText = "N/A"
    $uptimeText = "N/A"
    $recommendation = "Nenhuma recomendacao automatica."
    $topMem = @()
    $topCpu = @()

    $memAlert = script:Get-ReportAlertSafe "Get-MemoryAlert"
    if ($memAlert) { $memText = $memAlert.Message }

    $diskAlert = script:Get-ReportAlertSafe "Get-DiskAlert"
    if ($diskAlert) { $diskText = $diskAlert.Message }

    $upAlert = script:Get-ReportAlertSafe "Get-UptimeAlert"
    if ($upAlert) { $uptimeText = $upAlert.Message }

    $recs = @()
    if ($diskAlert -and $diskAlert.Status -in @("ATENCAO", "CRITICO")) {
        $recs += "Disco com pouco espaco: execute Limpeza segura (menu opcao 2)."
    }
    if ($memAlert -and $memAlert.Status -in @("ATENCAO", "CRITICO")) {
        $recs += "Memoria alta: feche processos pesados listados abaixo ou reinicie."
    }
    if ($upAlert -and $upAlert.Status -in @("ATENCAO", "CRITICO")) {
        $recs += "Uptime elevado: reinicie a maquina para liberar recursos."
    }
    if ($recs.Count -gt 0) { $recommendation = $recs -join " " }

    try {
        $topMem = Get-Process -ErrorAction SilentlyContinue |
            Sort-Object WorkingSet64 -Descending |
            Select-Object -First 10 Name,
            @{ N = "MemMB"; E = { [math]::Round($_.WorkingSet64 / 1MB, 1) } }
    } catch { }

    try {
        $topCpu = Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.CPU -gt 0 } |
            Sort-Object CPU -Descending |
            Select-Object -First 10 Name,
            @{ N = "CPUs"; E = { [math]::Round($_.CPU, 1) } }
    } catch { }

    return @{
        MemText = $memText
        DiskText = $diskText
        UptimeText = $uptimeText
        Recommendation = $recommendation
        TopMem = $topMem
        TopCpu = $topCpu
    }
}

function script:Collect-OneDriveReportData {
    $data = @{
        Status = "NA"
        ProcessRunning = "N/A"
        Executable = "N/A"
        LocalFolder = "N/A"
        LogsPath = "N/A"
        Lines = @()
    }
    if (-not (script:Test-IsWindowsSupportReport)) {
        $data.Lines += "OneDrive: N/A neste sistema"
        return $data
    }
    $proc = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    if ($proc) {
        $data.ProcessRunning = "Sim (PID $($proc.Id -join ','))"
        $data.Status = "OK"
    } else {
        $data.ProcessRunning = "Nao"
        $data.Status = "ATENCAO"
    }
    $data.Lines += "Processo: $($data.ProcessRunning)"

    $exePaths = @(
        "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
        "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
    )
    $exe = $exePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $exe -and (Get-Command Find-OneDriveExecutable -ErrorAction SilentlyContinue)) {
        $exe = Find-OneDriveExecutable
    }
    $data.Executable = if ($exe) { $exe } else { "Nao encontrado" }
    $data.Lines += "Executavel: $($data.Executable)"

    $folder = if ($env:OneDrive) { $env:OneDrive } elseif ($env:OneDriveConsumer) { $env:OneDriveConsumer } else { "N/A" }
    $data.LocalFolder = $folder
    $data.Lines += "Pasta local: $folder"

    $logsPath = "$env:LOCALAPPDATA\Microsoft\OneDrive\logs"
    $data.LogsPath = if (Test-Path $logsPath) { $logsPath } else { "Nao encontrado" }
    $data.Lines += "Logs: $($data.LogsPath)"

    return $data
}

function script:Collect-PrinterReportData {
    $data = @{
        Status = "NA"
        DefaultPrinter = "N/A"
        QueueInfo = "N/A"
        SpoolerStatus = "N/A"
        PrinterRows = @()
        Lines = @()
    }
    if (-not (script:Test-IsWindowsSupportReport)) {
        $data.Lines += "Impressoras: N/A neste sistema"
        return $data
    }
    try {
        $spooler = Get-Service -Name Spooler -ErrorAction Stop
        $data.SpoolerStatus = $spooler.Status.ToString()
        $data.Lines += "Spooler: $($data.SpoolerStatus)"
        if ($spooler.Status -ne "Running") { $data.Status = "ATENCAO" } else { $data.Status = "OK" }
    } catch {
        $data.SpoolerStatus = "N/A"
        $data.Status = "ATENCAO"
        $data.Lines += "Spooler: N/A"
    }
    try {
        $printers = Get-Printer -ErrorAction Stop
        foreach ($p in $printers) {
            $row = @{
                Name = $p.Name
                Default = $p.Default
                Status = $p.PrinterStatus
                Shared = $p.Shared
            }
            $data.PrinterRows += $row
            if ($p.Default) { $data.DefaultPrinter = $p.Name }
        }
        $data.Lines += "Impressoras instaladas: $($printers.Count)"
        try {
            $jobs = Get-PrintJob -ErrorAction SilentlyContinue
            $data.QueueInfo = if ($jobs) { "$($jobs.Count) trabalho(s) na fila" } else { "Fila vazia" }
        } catch {
            $data.QueueInfo = "N/A"
        }
        $data.Lines += "Fila: $($data.QueueInfo)"
    } catch {
        $data.Lines += "Lista de impressoras: N/A"
        if ($data.Status -eq "OK") { $data.Status = "ATENCAO" }
    }
    return $data
}

function script:Collect-WindowsReportData {
    $data = @{
        RebootPending = "N/A"
        SystemEvents = @()
        AppEvents = @()
        WindowsUpdate = "N/A"
        Lines = @()
    }
    if (-not (script:Test-IsWindowsSupportReport)) {
        $data.Lines += "Windows: N/A neste sistema"
        return $data
    }
    $rebootAlert = script:Get-ReportAlertSafe "Get-RebootPendingAlert"
    if ($rebootAlert) {
        $data.RebootPending = $rebootAlert.Message
        $data.Lines += $rebootAlert.Message
    }
    $startTime = (Get-Date).AddDays(-2)
    try {
        $sysEv = Get-WinEvent -FilterHashtable @{
            LogName = "System"; Level = 1, 2; StartTime = $startTime
        } -MaxEvents 10 -ErrorAction Stop
        foreach ($ev in $sysEv) {
            $data.SystemEvents += "$($ev.TimeCreated.ToString('yyyy-MM-dd HH:mm')) | ID $($ev.Id) | $($ev.LevelDisplayName) | $($ev.ProviderName)"
        }
    } catch {
        $data.SystemEvents += "N/A: $_"
    }
    try {
        $appEv = Get-WinEvent -FilterHashtable @{
            LogName = "Application"; Level = 1, 2; StartTime = $startTime
        } -MaxEvents 10 -ErrorAction Stop
        foreach ($ev in $appEv) {
            $data.AppEvents += "$($ev.TimeCreated.ToString('yyyy-MM-dd HH:mm')) | ID $($ev.Id) | $($ev.LevelDisplayName) | $($ev.ProviderName)"
        }
    } catch {
        $data.AppEvents += "N/A: $_"
    }
    try {
        $hotfix = Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First 5
        if ($hotfix) {
            $data.WindowsUpdate = ($hotfix | ForEach-Object { "$($_.HotFixID) ($($_.InstalledOn))" }) -join "; "
        }
    } catch {
        $data.WindowsUpdate = "N/A"
    }
    $data.Lines += "Windows Update (hotfix recentes): $($data.WindowsUpdate)"
    return $data
}


function script:Get-EventInterpretation {
    param(
        [int]$EventId,
        [string]$Provider
    )

    $key = "$EventId"
    $rules = @(
        @{ Match = { $EventId -eq 41 -and $Provider -like "*Kernel-Power*" }; Description = "Desligamento inesperado detectado."; Impact = "Medio"; Action = "Verificar energia ou desligamentos forcados."; Status = "ATENCAO" }
        @{ Match = { $EventId -eq 6008 }; Description = "Sistema desligado incorretamente."; Impact = "Medio"; Action = "Verificar quedas de energia ou reinicios forcados."; Status = "ATENCAO" }
        @{ Match = { $EventId -eq 20 -and $Provider -like "*WindowsUpdateClient*" }; Description = "Falha recente em atualizacao do Windows."; Impact = "Medio"; Action = "Executar reparo do Windows Update (menu Reparos Windows)." ; Status = "ATENCAO" }
        @{ Match = { $EventId -eq 8198 -and $Provider -like "*Security-SPP*" }; Description = "Possivel problema de licenciamento Microsoft."; Impact = "Baixo"; Action = "Verificar ativacao do Windows/Office com o suporte."; Status = "ATENCAO" }
        @{ Match = { $EventId -eq 1040 -and $Provider -like "*TPM-WMI*" }; Description = "Erro relacionado ao TPM."; Impact = "Baixo"; Action = "Verificar firmware/BIOS e drivers do TPM."; Status = "ATENCAO" }
    )

    foreach ($r in $rules) {
        if (& $r.Match) {
            return [PSCustomObject]@{
                Description = $r.Description
                Impact = $r.Impact
                Action = $r.Action
                Status = $r.Status
            }
        }
    }

    return [PSCustomObject]@{
        Description = "Evento critico/erro do sistema ($Provider ID $EventId)."
        Impact = "Medio"
        Action = "Investigar no Visualizador de Eventos do Windows."
        Status = "ATENCAO"
    }
}

function script:Format-BytesHuman {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function script:Collect-HardwareReportData {
    $data = @{
        Manufacturer = "N/A"
        Model = "N/A"
        Serial = "N/A"
        CPU = "N/A"
        Cores = "N/A"
        RamGB = "N/A"
        DiskTotalGB = "N/A"
        Windows = "N/A"
        Build = "N/A"
        Summary = "N/A"
    }

    if (script:Test-IsWindowsSupportReport) {
        try {
            $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            $data.Manufacturer = if ($cs.Manufacturer) { $cs.Manufacturer } else { "N/A" }
            $data.Model = if ($cs.Model) { $cs.Model } else { "N/A" }
            $data.RamGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        } catch { }

        try {
            $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
            $data.Serial = if ($bios.SerialNumber) { $bios.SerialNumber } else { "N/A" }
        } catch { }

        try {
            $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
            $data.CPU = $cpu.Name.Trim()
            $data.Cores = $cpu.NumberOfLogicalProcessors
        } catch { }

        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $data.Windows = $os.Caption
            $data.Build = $os.BuildNumber
        } catch { }

        try {
            $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
            $data.DiskTotalGB = [math]::Round($disk.Size / 1GB, 1)
        } catch { }
    } else {
        $data.CPU = "N/A (ambiente nao-Windows)"
        $data.Cores = [System.Environment]::ProcessorCount
        try {
            if (Test-Path /proc/meminfo) {
                $raw = (Get-Content /proc/meminfo | Where-Object { $_ -match '^MemTotal:' }) -replace '[^\d]', ''
                $data.RamGB = [math]::Round([long]$raw / 1MB, 1)
            }
        } catch { }
        $data.Windows = [System.Environment]::OSVersion.VersionString
    }

    $parts = @()
    if ($data.Manufacturer -ne "N/A" -or $data.Model -ne "N/A") {
        $parts += "$($data.Manufacturer) $($data.Model)".Trim()
    }
    if ($data.CPU -ne "N/A") { $parts += $data.CPU }
    if ($data.RamGB -ne "N/A") { $parts += "$($data.RamGB) GB RAM" }
    if ($data.DiskTotalGB -ne "N/A") { $parts += "Disco $($data.DiskTotalGB) GB" }
    if ($data.Windows -ne "N/A") { $parts += $data.Windows }
    if ($parts.Count -gt 0) { $data.Summary = $parts -join " | " }

    return $data
}

function script:Collect-MemoryReportData {
    $data = @{
        InstalledGB = "N/A"
        FreeGB = "N/A"
        UsedPct = "N/A"
        Status = "NA"
        Diagnosis = "N/A"
        Recommendation = "N/A"
    }

    if (script:Test-IsWindowsSupportReport) {
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $total = $os.TotalVisibleMemorySize / 1MB
            $free = $os.FreePhysicalMemory / 1MB
            $usedPct = [math]::Round(($total - $free) / $total * 100, 0)
            $data.InstalledGB = [math]::Round($total, 1)
            $data.FreeGB = [math]::Round($free, 1)
            $data.UsedPct = $usedPct

            if ($total -lt 6) {
                $data.Status = "ATENCAO"
                $data.Diagnosis = "ATENCAO - A maquina possui apenas $([math]::Round($total,0)) GB de RAM. Windows pode apresentar lentidao."
                $data.Recommendation = "Expandir para 8 GB ou mais."
            } elseif ($usedPct -gt 90) {
                $data.Status = "CRITICO"
                $data.Diagnosis = "CRITICO - Memoria quase esgotada ($usedPct% em uso)."
                $data.Recommendation = "Fechar programas pesados ou reiniciar a maquina."
            } elseif ($usedPct -gt 80) {
                $data.Status = "ATENCAO"
                $data.Diagnosis = "ATENCAO - Uso de memoria elevado ($usedPct%)."
                $data.Recommendation = "Monitorar processos pesados e considerar mais RAM."
            } else {
                $data.Status = "OK"
                $data.Diagnosis = "OK - Memoria dentro do esperado ($usedPct% em uso)."
                $data.Recommendation = "Nenhuma acao necessaria."
            }
        } catch {
            $data.Diagnosis = "N/A - Erro ao coletar memoria."
        }
    } else {
        $data.Diagnosis = "N/A neste sistema operacional."
    }

    return $data
}

function script:Collect-DiskReportData {
    $data = @{
        TotalGB = "N/A"
        FreeGB = "N/A"
        UsedGB = "N/A"
        UsedPct = "N/A"
        Status = "NA"
        TopFolders = @()
        Recommendation = "N/A"
    }

    if (script:Test-IsWindowsSupportReport) {
        try {
            $drive = Get-PSDrive -Name C -PSProvider FileSystem -ErrorAction Stop
            $total = $drive.Used + $drive.Free
            if ($total -gt 0) {
                $data.TotalGB = [math]::Round($total / 1GB, 1)
                $data.FreeGB = [math]::Round($drive.Free / 1GB, 1)
                $data.UsedGB = [math]::Round($drive.Used / 1GB, 1)
                $data.UsedPct = [math]::Round($drive.Used / $total * 100, 0)
                $pctFree = 100 - $data.UsedPct
                if ($pctFree -lt 10) {
                    $data.Status = "CRITICO"
                    $data.Recommendation = "Disco quase cheio. Execute Limpeza segura (menu opcao 2) urgentemente."
                } elseif ($pctFree -lt 15) {
                    $data.Status = "ATENCAO"
                    $data.Recommendation = "Pouco espaco livre. Execute Limpeza segura para liberar espaco."
                } else {
                    $data.Status = "OK"
                    $data.Recommendation = "Espaco em disco adequado."
                }
            }
        } catch { }

        $profile = $env:USERPROFILE
        $folderNames = @("Downloads", "Desktop", "Documents", "OneDrive")
        foreach ($name in $folderNames) {
            $path = Join-Path $profile $name
            if ($name -eq "OneDrive" -and $env:OneDrive) { $path = $env:OneDrive }
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if (-not $size) { $size = 0 }
                    $data.TopFolders += [PSCustomObject]@{
                        Name = $name
                        Path = $path
                        Size = script:Format-BytesHuman $size
                        SizeBytes = $size
                    }
                } catch { }
            }
        }
        $data.TopFolders = $data.TopFolders | Sort-Object SizeBytes -Descending | Select-Object -First 10
    } else {
        $data.Recommendation = "N/A neste sistema operacional."
    }

    return $data
}

function script:Collect-CriticalEventsData {
    $events = @()
    if (-not (script:Test-IsWindowsSupportReport)) {
        return @{ Events = $events; Status = "NA" }
    }

    $startTime = (Get-Date).AddDays(-7)
    try {
        $raw = Get-WinEvent -FilterHashtable @{
            LogName = @("System", "Application")
            Level = 1, 2
            StartTime = $startTime
        } -MaxEvents 50 -ErrorAction Stop

        foreach ($ev in $raw) {
            $interp = script:Get-EventInterpretation -EventId $ev.Id -Provider $ev.ProviderName
            $events += [PSCustomObject]@{
                Date = $ev.TimeCreated.ToString("yyyy-MM-dd HH:mm")
                Event = "$($ev.ProviderName) ID $($ev.Id)"
                Description = $interp.Description
                Impact = $interp.Impact
                Action = $interp.Action
                Status = $interp.Status
            }
        }
    } catch { }

    $events = $events | Select-Object -First 10
    $status = if ($events.Count -eq 0) { "OK" } else { "ATENCAO" }
    return @{ Events = $events; Status = $status; Count = $events.Count }
}

function script:Collect-StartupProgramsData {
    $programs = @()
    if (-not (script:Test-IsWindowsSupportReport)) {
        return @{ Programs = $programs; Status = "NA"; Diagnosis = "N/A" }
    }

    try {
        $items = Get-CimInstance Win32_StartupCommand -ErrorAction Stop
        foreach ($item in $items) {
            $programs += [PSCustomObject]@{
                Name = $item.Name
                Status = "Ativo"
                Manufacturer = if ($item.Location) { $item.Location } else { "N/A" }
            }
        }
    } catch {
        try {
            $runKeys = @(
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
            )
            foreach ($key in $runKeys) {
                if (Test-Path $key) {
                    $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
                    $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                        $programs += [PSCustomObject]@{
                            Name = $_.Name
                            Status = "Ativo"
                            Manufacturer = $key
                        }
                    }
                }
            }
        } catch { }
    }

    $count = $programs.Count
    $diag = if ($count -le 5) { "Poucos programas ($count)" }
            elseif ($count -le 12) { "Moderado ($count programas)" }
            else { "Muitos programas ($count) - pode aumentar tempo de boot" }

    $status = if ($count -le 12) { "OK" } else { "ATENCAO" }
    return @{ Programs = $programs; Status = $status; Diagnosis = $diag; Count = $count }
}

function script:Collect-DefenderReportData {
    $data = @{
        Active = "N/A"
        LastUpdate = "N/A"
        Signatures = "N/A"
        RealTime = "N/A"
        Status = "NA"
    }

    if (-not (script:Test-IsWindowsSupportReport)) {
        return $data
    }

    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $data.Active = if ($mp.AMServiceEnabled) { "Ativo" } else { "Inativo" }
        $data.LastUpdate = if ($mp.AntivirusSignatureLastUpdated) { $mp.AntivirusSignatureLastUpdated.ToString("yyyy-MM-dd HH:mm") } else { "N/A" }
        $data.Signatures = if ($mp.AntivirusSignatureVersion) { $mp.AntivirusSignatureVersion } else { "N/A" }
        $data.RealTime = if ($mp.RealTimeProtectionEnabled) { "Sim" } else { "Nao" }

        if (-not $mp.AMServiceEnabled -or -not $mp.RealTimeProtectionEnabled) {
            $data.Status = "CRITICO"
        } elseif ($mp.AntivirusSignatureLastUpdated -lt (Get-Date).AddDays(-7)) {
            $data.Status = "ATENCAO"
        } else {
            $data.Status = "OK"
        }
    } catch {
        $data.Active = "N/A (nao disponivel)"
        $data.Status = "NA"
    }

    return $data
}

function script:Get-HealthScoreLabel {
    param([int]$Score)
    if ($Score -ge 95) { return "EXCELENTE" }
    if ($Score -ge 80) { return "BOM" }
    if ($Score -ge 60) { return "ATENCAO" }
    return "CRITICO"
}

function script:Get-HealthScoreClass {
    param([int]$Score)
    if ($Score -ge 80) { return "ok" }
    if ($Score -ge 60) { return "atencao" }
    return "critico"
}

function script:StatusToScorePenalty {
    param([string]$Status, [int]$Critico = 20, [int]$Atencao = 10)
    switch ($Status) {
        "CRITICO" { return $Critico }
        "ATENCAO" { return $Atencao }
        default { return 0 }
    }
}

function script:Calculate-HealthScore {
    param([hashtable]$Metrics)

    $score = 100
    $areas = @()

    $components = @(
        @{ Label = "Disco"; Status = $Metrics.Disk.Status; PenCrit = 18; PenAt = 8 }
        @{ Label = "Memoria"; Status = $Metrics.Memory.Status; PenCrit = 18; PenAt = 8 }
        @{ Label = "Internet"; Status = $Metrics.Network.Status; PenCrit = 15; PenAt = 8 }
        @{ Label = "Windows Update"; Status = $Metrics.WinUpdate.Status; PenCrit = 10; PenAt = 6 }
        @{ Label = "Eventos Criticos"; Status = $Metrics.Events.Status; PenCrit = 12; PenAt = 6 }
        @{ Label = "RDP"; Status = $Metrics.Rdp.Status; PenCrit = 5; PenAt = 3 }
        @{ Label = "OneDrive"; Status = $Metrics.OneDrive.Status; PenCrit = 5; PenAt = 3 }
        @{ Label = "Impressoras"; Status = $Metrics.Printers.Status; PenCrit = 5; PenAt = 3 }
        @{ Label = "Defender"; Status = $Metrics.Defender.Status; PenCrit = 15; PenAt = 8 }
    )

    foreach ($c in $components) {
        $pen = script:StatusToScorePenalty -Status $c.Status -Critico $c.PenCrit -Atencao $c.PenAt
        $score -= $pen
        $areas += [PSCustomObject]@{
            Label = $c.Label
            Status = if ($c.Status) { $c.Status } else { "NA" }
            Penalty = $pen
        }
    }

    if ($score -lt 0) { $score = 0 }
    if ($score -gt 100) { $score = 100 }

    return @{
        Score = $score
        Label = script:Get-HealthScoreLabel -Score $score
        Class = script:Get-HealthScoreClass -Score $score
        Areas = $areas
    }
}

function script:Build-ProblemsFromData {
    param(
        [array]$Alerts,
        [hashtable]$RdpData,
        [hashtable]$EventsData,
        [hashtable]$MemoryData,
        [hashtable]$DiskData,
        [hashtable]$DefenderData
    )

    $problems = @()
    $seen = @{}

    foreach ($a in $Alerts) {
        if ($a.Status -eq "OK" -or $a.Status -eq "NA") { continue }
        $problems += [PSCustomObject]@{
            Status = $a.Status
            Description = $a.Message
            Impact = if ($a.Status -eq "CRITICO") { "Alto" } else { "Medio" }
            Action = if ($a.Suggestion) { $a.Suggestion } else { "Verifique no menu Atlas." }
        }
    }

    foreach ($ev in $EventsData.Events) {
        $key = $ev.Event
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $problems += [PSCustomObject]@{
            Status = $ev.Status
            Description = $ev.Description
            Impact = $ev.Impact
            Action = $ev.Action
        }
    }

    if ($MemoryData.Status -in @("ATENCAO", "CRITICO")) {
        $problems += [PSCustomObject]@{
            Status = $MemoryData.Status
            Description = $MemoryData.Diagnosis
            Impact = if ($MemoryData.Status -eq "CRITICO") { "Alto" } else { "Medio" }
            Action = $MemoryData.Recommendation
        }
    }

    if ($DiskData.Status -in @("ATENCAO", "CRITICO")) {
        $problems += [PSCustomObject]@{
            Status = $DiskData.Status
            Description = "Disco C: $($DiskData.UsedPct)% usado - $($DiskData.FreeGB) GB livres"
            Impact = if ($DiskData.Status -eq "CRITICO") { "Alto" } else { "Medio" }
            Action = $DiskData.Recommendation
        }
    }

    if ($DefenderData.Status -in @("ATENCAO", "CRITICO")) {
        $problems += [PSCustomObject]@{
            Status = $DefenderData.Status
            Description = "Windows Defender: $($DefenderData.Active) | Tempo real: $($DefenderData.RealTime)"
            Impact = if ($DefenderData.Status -eq "CRITICO") { "Alto" } else { "Medio" }
            Action = "Verificar protecao antivirus e atualizar assinaturas."
        }
    }

    if ($RdpData.Status -eq "ATENCAO") {
        $problems += [PSCustomObject]@{
            Status = "ATENCAO"
            Description = "RDP: $($RdpData.Detail)"
            Impact = "Medio"
            Action = "Verificar TermService e firewall (porta 3389)."
        }
    }

    if ($problems.Count -eq 0) {
        $problems += [PSCustomObject]@{
            Status = "OK"
            Description = "Nenhum problema relevante detectado nos checks automaticos."
            Impact = "Baixo"
            Action = "Manter monitoramento periodico."
        }
    }

    return $problems
}

function script:Build-SmartRecommendations {
    param(
        [array]$Alerts,
        [hashtable]$MemoryData,
        [hashtable]$DiskData,
        [hashtable]$EventsData,
        [hashtable]$StartupData,
        [hashtable]$DefenderData,
        [hashtable]$Slowness,
        [hashtable]$RdpData
    )

    $recs = [System.Collections.ArrayList]@()

    if ($MemoryData.InstalledGB -ne "N/A" -and [double]$MemoryData.InstalledGB -lt 6) {
        [void]$recs.Add("Memoria insuficiente ($($MemoryData.InstalledGB) GB). Adicionar RAM para melhor desempenho.")
    } elseif ($MemoryData.Status -in @("ATENCAO", "CRITICO")) {
        [void]$recs.Add($MemoryData.Recommendation)
    }

    if ($DiskData.Status -in @("ATENCAO", "CRITICO")) {
        [void]$recs.Add($DiskData.Recommendation)
    }

    $hasPowerEvent = $false
    $hasWuEvent = $false
    foreach ($ev in $EventsData.Events) {
        if ($ev.Event -like "*Kernel-Power*41*" -or $ev.Description -like "*Desligamento inesperado*") {
            $hasPowerEvent = $true
        }
        if ($ev.Event -like "*WindowsUpdateClient*20*" -or $ev.Description -like "*atualizacao*") {
            $hasWuEvent = $true
        }
    }
    if ($hasPowerEvent) {
        [void]$recs.Add("Foram detectados desligamentos inesperados. Verificar energia e hardware.")
    }
    if ($hasWuEvent) {
        [void]$recs.Add("Atualizacoes falharam recentemente. Executar reparo do Windows Update.")
    }

    if ($StartupData.Count -gt 12) {
        [void]$recs.Add("Muitos programas na inicializacao ($($StartupData.Count)). Desative itens desnecessarios.")
    }

    if ($DefenderData.Status -in @("ATENCAO", "CRITICO")) {
        [void]$recs.Add("Verificar Windows Defender e atualizar assinaturas de virus.")
    }

    foreach ($a in $Alerts) {
        if ($a.Suggestion) { [void]$recs.Add($a.Suggestion) }
    }

    if ($RdpData.Status -eq "ATENCAO") {
        [void]$recs.Add("RDP indisponivel: verificar TermService e firewall.")
    }

    $unique = $recs | Select-Object -Unique
    if ($unique.Count -eq 0) {
        return @("Sistema saudavel. Gere novo relatorio apos alteracoes significativas.")
    }
    return @($unique)
}

function script:Render-AtlasSupportHtml {
    param([hashtable]$Report)

    $h = $Report.Header
    $health = $Report.Health
    $problems = $Report.Problems
    $recs = $Report.Recommendations
    $hw = $Report.Hardware
    $mem = $Report.Memory
    $disk = $Report.Disk
    $net = $Report.Network
    $rdp = $Report.Rdp
    $od = $Report.OneDrive
    $pr = $Report.Printers
    $win = $Report.Windows
    $events = $Report.Events
    $startup = $Report.Startup
    $defender = $Report.Defender
    $slow = $Report.Slowness

    $iconOk = "&#10004;"
    $iconWarn = "&#9888;"
    $iconCrit = "&#10006;"

    $healthIcon = switch ($health.Class) {
        "ok" { $iconOk }
        "atencao" { $iconWarn }
        default { $iconCrit }
    }

    $areaCards = ""
    foreach ($a in $health.Areas) {
        $suffix = script:Get-StatusCssSuffix $a.Status
        $areaCards += "<div class=`"score-area card-$suffix`"><span class=`"area-label`">$(script:Escape-HtmlText $a.Label)</span><span class=`"area-status`">$(script:Escape-HtmlText $a.Status)</span></div>`n"
    }

    $problemRows = ""
    foreach ($p in $problems) {
        $suffix = script:Get-StatusCssSuffix $p.Status
        $problemRows += "<tr class=`"row-$suffix`"><td><span class=`"badge badge-$suffix`">$(script:Escape-HtmlText $p.Status)</span></td><td>$(script:Escape-HtmlText $p.Description)</td><td>$(script:Escape-HtmlText $p.Impact)</td><td>$(script:Escape-HtmlText $p.Action)</td></tr>`n"
    }

    $recBlocks = ""
    $ri = 1
    foreach ($r in $recs) {
        $recBlocks += "<div class=`"reco-card`"><div class=`"reco-title`">Recomendacao $ri</div><p>$(script:Escape-HtmlText $r)</p></div>`n"
        $ri++
    }

    $folderRows = ""
    foreach ($f in $disk.TopFolders) {
        $folderRows += "<tr><td>$(script:Escape-HtmlText $f.Name)</td><td>$(script:Escape-HtmlText $f.Size)</td><td>$(script:Escape-HtmlText $f.Path)</td></tr>`n"
    }
    if (-not $folderRows) { $folderRows = "<tr><td colspan=`"3`">N/A</td></tr>" }

    $eventRows = ""
    foreach ($ev in $events.Events) {
        $suffix = script:Get-StatusCssSuffix $ev.Status
        $eventRows += "<tr class=`"row-$suffix`"><td>$(script:Escape-HtmlText $ev.Date)</td><td>$(script:Escape-HtmlText $ev.Event)</td><td>$(script:Escape-HtmlText $ev.Description)</td><td>$(script:Escape-HtmlText $ev.Impact)</td></tr>`n"
    }
    if (-not $eventRows) { $eventRows = "<tr><td colspan=`"4`">Nenhum evento critico relevante nos ultimos 7 dias</td></tr>" }

    $startupRows = ""
    foreach ($sp in $startup.Programs) {
        $startupRows += "<tr><td>$(script:Escape-HtmlText $sp.Name)</td><td>$(script:Escape-HtmlText $sp.Status)</td><td>$(script:Escape-HtmlText $sp.Manufacturer)</td></tr>`n"
    }
    if (-not $startupRows) { $startupRows = "<tr><td colspan=`"3`">Nenhum item encontrado</td></tr>" }

    $topMemRows = ""
    foreach ($proc in $slow.TopMem) {
        $topMemRows += "<tr><td>$(script:Escape-HtmlText $proc.Name)</td><td>$($proc.MemMB) MB</td></tr>`n"
    }
    if (-not $topMemRows) { $topMemRows = "<tr><td colspan=`"2`">N/A</td></tr>" }

    $printerRows = ""
    foreach ($row in $pr.PrinterRows) {
        $def = if ($row.Default) { "Sim" } else { "Nao" }
        $printerRows += "<tr><td>$(script:Escape-HtmlText $row.Name)</td><td>$def</td><td>$(script:Escape-HtmlText ([string]$row.Status))</td></tr>`n"
    }
    if (-not $printerRows) { $printerRows = "<tr><td colspan=`"3`">N/A</td></tr>" }

    $netLines = ($net.Lines | ForEach-Object { script:Escape-HtmlText $_ }) -join "<br/>"

    return @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Atlas - Relatorio de Suporte</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Segoe UI, Tahoma, Arial, sans-serif; background: #eef1f5; color: #2c3e50; line-height: 1.6; }
        .wrap { max-width: 1100px; margin: 0 auto; padding: 24px 20px 48px; }
        .header { background: linear-gradient(135deg, #1c3faa 0%, #364fc7 100%); color: #fff; padding: 28px 32px; border-radius: 12px; margin-bottom: 24px; }
        .header h1 { font-size: 26px; margin-bottom: 10px; }
        .meta { font-size: 14px; opacity: 0.95; line-height: 1.8; }
        .section { background: #fff; padding: 28px 32px; margin-bottom: 24px; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
        .section h2 { font-size: 20px; color: #1c3faa; margin-bottom: 20px; padding-bottom: 12px; border-bottom: 2px solid #e7ebf3; }
        .health-box { text-align: center; padding: 32px 24px; border-radius: 12px; margin-bottom: 24px; }
        .health-ok { background: linear-gradient(135deg, #d3f9d8, #b2f2bb); border: 2px solid #2f9e44; }
        .health-atencao { background: linear-gradient(135deg, #fff9db, #ffec99); border: 2px solid #f08c00; }
        .health-critico { background: linear-gradient(135deg, #ffe3e3, #ffc9c9); border: 2px solid #e03131; }
        .health-title { font-size: 14px; text-transform: uppercase; letter-spacing: 0.08em; color: #495057; margin-bottom: 8px; }
        .health-score { font-size: 56px; font-weight: 800; line-height: 1; }
        .health-label { font-size: 22px; font-weight: 700; margin-top: 8px; }
        .health-icon { font-size: 28px; margin-bottom: 8px; }
        .score-areas { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 12px; margin-top: 20px; }
        .score-area { padding: 12px 14px; border-radius: 8px; text-align: center; }
        .area-label { display: block; font-size: 11px; text-transform: uppercase; color: #495057; }
        .area-status { display: block; font-size: 16px; font-weight: 700; margin-top: 4px; }
        .card-ok { background: #ebfbee; border-left: 4px solid #2f9e44; }
        .card-atencao { background: #fff9db; border-left: 4px solid #f08c00; }
        .card-critico { background: #fff5f5; border-left: 4px solid #e03131; }
        .card-na { background: #f1f3f5; border-left: 4px solid #868e96; }
        table { width: 100%; border-collapse: collapse; font-size: 14px; margin-top: 10px; }
        th, td { padding: 12px 14px; text-align: left; border-bottom: 1px solid #e9ecef; }
        th { background: #f1f3f5; font-weight: 600; }
        tr:hover td { background: #f8f9fa; }
        .badge { display: inline-block; padding: 4px 10px; border-radius: 4px; font-size: 11px; font-weight: 700; }
        .badge-ok { background: #d3f9d8; color: #2b8a3e; }
        .badge-atencao { background: #ffec99; color: #e67700; }
        .badge-critico { background: #ffc9c9; color: #c92a2a; }
        .detail-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 16px; }
        .detail-item { padding: 14px 16px; background: #f8f9fa; border-radius: 8px; }
        .detail-item strong { display: block; font-size: 12px; color: #868e96; text-transform: uppercase; margin-bottom: 4px; }
        .detail-item span { font-size: 15px; font-weight: 600; }
        .diag-box { padding: 16px 20px; border-radius: 8px; margin: 12px 0; }
        .diag-ok { background: #ebfbee; border-left: 4px solid #2f9e44; }
        .diag-atencao { background: #fff9db; border-left: 4px solid #f08c00; }
        .diag-critico { background: #fff5f5; border-left: 4px solid #e03131; }
        .reco-card { padding: 16px 20px; margin-bottom: 12px; background: #e7f5ff; border-left: 4px solid #1c7ed6; border-radius: 6px; }
        .reco-title { font-weight: 700; color: #1c3faa; margin-bottom: 6px; }
        .summary-line { font-size: 16px; padding: 12px 16px; background: #f1f3f5; border-radius: 8px; margin-bottom: 16px; }
        .footer { text-align: center; font-size: 12px; color: #868e96; margin-top: 24px; }
        .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        @media (max-width: 768px) { .two-col { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
<div class="wrap">
    <div class="header">
        <h1>Atlas - Relatorio de Suporte da Maquina</h1>
        <div class="meta">
            Data/hora: $(script:Escape-HtmlText $h.DateTime)<br/>
            Hostname: $(script:Escape-HtmlText $h.Hostname) | Usuario: $(script:Escape-HtmlText $h.Username)<br/>
            SO: $(script:Escape-HtmlText $h.OsCaption) | PowerShell: $(script:Escape-HtmlText $h.PowerShellVersion)
        </div>
    </div>

    <div class="section">
        <h2>Saude Geral da Maquina</h2>
        <div class="health-box health-$(script:Escape-HtmlText $health.Class)">
            <div class="health-icon">$healthIcon</div>
            <div class="health-title">Score de Saude</div>
            <div class="health-score">$($health.Score) / 100</div>
            <div class="health-label">$(script:Escape-HtmlText $health.Label)</div>
        </div>
        <div class="score-areas">$areaCards</div>
    </div>

    <div class="section">
        <h2>Resumo Executivo</h2>
        <p class="summary-line">$(script:Escape-HtmlText $Report.ExecutiveSummary)</p>
        <p><strong>Suporte precisa agir?</strong> $(script:Escape-HtmlText $Report.SupportAction)</p>
    </div>

    <div class="section">
        <h2>Problemas Detectados</h2>
        <table>
            <thead><tr><th>Status</th><th>Descricao</th><th>Impacto</th><th>Acao</th></tr></thead>
            <tbody>$problemRows</tbody>
        </table>
    </div>

    <div class="section">
        <h2>Recomendacoes</h2>
        $recBlocks
    </div>

    <div class="section">
        <h2>Hardware</h2>
        <p class="summary-line">$(script:Escape-HtmlText $hw.Summary)</p>
        <div class="detail-grid">
            <div class="detail-item"><strong>Fabricante</strong><span>$(script:Escape-HtmlText $hw.Manufacturer)</span></div>
            <div class="detail-item"><strong>Modelo</strong><span>$(script:Escape-HtmlText $hw.Model)</span></div>
            <div class="detail-item"><strong>Serial</strong><span>$(script:Escape-HtmlText $hw.Serial)</span></div>
            <div class="detail-item"><strong>CPU</strong><span>$(script:Escape-HtmlText $hw.CPU)</span></div>
            <div class="detail-item"><strong>Nucleos</strong><span>$(script:Escape-HtmlText ([string]$hw.Cores))</span></div>
            <div class="detail-item"><strong>RAM</strong><span>$(script:Escape-HtmlText ([string]$hw.RamGB)) GB</span></div>
            <div class="detail-item"><strong>Disco Total</strong><span>$(script:Escape-HtmlText ([string]$hw.DiskTotalGB)) GB</span></div>
            <div class="detail-item"><strong>Windows</strong><span>$(script:Escape-HtmlText $hw.Windows)</span></div>
            <div class="detail-item"><strong>Build</strong><span>$(script:Escape-HtmlText ([string]$hw.Build))</span></div>
        </div>
    </div>

    <div class="section">
        <h2>Memoria</h2>
        <div class="detail-grid">
            <div class="detail-item"><strong>Instalada</strong><span>$(script:Escape-HtmlText ([string]$mem.InstalledGB)) GB</span></div>
            <div class="detail-item"><strong>Livre</strong><span>$(script:Escape-HtmlText ([string]$mem.FreeGB)) GB</span></div>
            <div class="detail-item"><strong>Uso</strong><span>$(script:Escape-HtmlText ([string]$mem.UsedPct))%</span></div>
        </div>
        <div class="diag-box diag-$(script:Get-StatusCssSuffix $mem.Status)">
            <strong>Diagnostico:</strong> $(script:Escape-HtmlText $mem.Diagnosis)<br/>
            <strong>Recomendacao:</strong> $(script:Escape-HtmlText $mem.Recommendation)
        </div>
    </div>

    <div class="section">
        <h2>Disco</h2>
        <div class="detail-grid">
            <div class="detail-item"><strong>Total</strong><span>$(script:Escape-HtmlText ([string]$disk.TotalGB)) GB</span></div>
            <div class="detail-item"><strong>Livre</strong><span>$(script:Escape-HtmlText ([string]$disk.FreeGB)) GB</span></div>
            <div class="detail-item"><strong>Usado</strong><span>$(script:Escape-HtmlText ([string]$disk.UsedGB)) GB ($($disk.UsedPct)%)</span></div>
        </div>
        <p style="margin-top:16px;"><strong>Maiores pastas do perfil</strong></p>
        <table><thead><tr><th>Pasta</th><th>Tamanho</th><th>Caminho</th></tr></thead><tbody>$folderRows</tbody></table>
        <div class="diag-box diag-$(script:Get-StatusCssSuffix $disk.Status)">$(script:Escape-HtmlText $disk.Recommendation)</div>
    </div>

    <div class="section">
        <h2>Rede e Internet</h2>
        <div class="detail-grid">
            <div class="detail-item"><strong>IP</strong><span>$(script:Escape-HtmlText $net.PrimaryIp)</span></div>
            <div class="detail-item"><strong>Gateway</strong><span>$(script:Escape-HtmlText $net.Gateway)</span></div>
            <div class="detail-item"><strong>DNS</strong><span>$(script:Escape-HtmlText $net.DnsConfig)</span></div>
        </div>
        <p style="margin-top:12px;">$netLines</p>
    </div>

    <div class="section">
        <h2>RDP</h2>
        <p><span class="badge badge-$(script:Get-StatusCssSuffix $rdp.Status)">$(script:Escape-HtmlText $rdp.Status)</span> $(script:Escape-HtmlText $rdp.Detail)</p>
    </div>

    <div class="section">
        <h2>OneDrive</h2>
        <p><span class="badge badge-$(script:Get-StatusCssSuffix $od.Status)">$(script:Escape-HtmlText $od.Status)</span> Processo: $(script:Escape-HtmlText $od.ProcessRunning)</p>
    </div>

    <div class="section">
        <h2>Impressoras</h2>
        <p>Spooler: $(script:Escape-HtmlText $pr.SpoolerStatus) | Padrao: $(script:Escape-HtmlText $pr.DefaultPrinter)</p>
        <table><thead><tr><th>Nome</th><th>Padrao</th><th>Status</th></tr></thead><tbody>$printerRows</tbody></table>
    </div>

    <div class="section">
        <h2>Windows</h2>
        <p><strong>Reboot pendente:</strong> $(script:Escape-HtmlText $win.RebootPending)</p>
        <p><strong>Windows Update:</strong> $(script:Escape-HtmlText $win.WindowsUpdate)</p>
    </div>

    <div class="section">
        <h2>Eventos Criticos</h2>
        <table>
            <thead><tr><th>Data</th><th>Evento</th><th>Descricao</th><th>Impacto</th></tr></thead>
            <tbody>$eventRows</tbody>
        </table>
    </div>

    <div class="section">
        <h2>Programas de Inicializacao</h2>
        <p><strong>Diagnostico:</strong> $(script:Escape-HtmlText $startup.Diagnosis)</p>
        <table><thead><tr><th>Nome</th><th>Status</th><th>Origem</th></tr></thead><tbody>$startupRows</tbody></table>
    </div>

    <div class="section">
        <h2>Windows Defender</h2>
        <div class="detail-grid">
            <div class="detail-item"><strong>Status</strong><span>$(script:Escape-HtmlText $defender.Active)</span></div>
            <div class="detail-item"><strong>Ultima atualizacao</strong><span>$(script:Escape-HtmlText $defender.LastUpdate)</span></div>
            <div class="detail-item"><strong>Assinaturas</strong><span>$(script:Escape-HtmlText $defender.Signatures)</span></div>
            <div class="detail-item"><strong>Tempo real</strong><span>$(script:Escape-HtmlText $defender.RealTime)</span></div>
        </div>
        <p style="margin-top:12px;"><span class="badge badge-$(script:Get-StatusCssSuffix $defender.Status)">$(script:Escape-HtmlText $defender.Status)</span></p>
    </div>

    <div class="section">
        <h2>Processos Pesados</h2>
        <table><thead><tr><th>Processo</th><th>Memoria</th></tr></thead><tbody>$topMemRows</tbody></table>
    </div>

    <div class="footer">
        <p>Atlas - Assistente de Manutencao Windows</p>
        <p>Relatorio gerado em $(script:Escape-HtmlText $h.DateTime)</p>
    </div>
</div>
</body>
</html>
"@
}

function New-AtlasSupportHtmlReport {
    Write-Log -Message "Iniciando geracao de relatorio HTML profissional" -Level "INFO"

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $htmlFile = Join-Path $desktopPath "Atlas_Relatorio_$timestamp.html"

    if (-not (Test-Path $desktopPath)) {
        Write-Log -Message "Area de trabalho nao encontrada: $desktopPath" -Level "ERROR"
        Write-Host "Erro: Area de trabalho nao encontrada." -ForegroundColor Red
        return $null
    }

    $osCaption = [System.Environment]::OSVersion.VersionString
    if (script:Test-IsWindowsSupportReport) {
        try {
            $wmiOs = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $osCaption = $wmiOs.Caption
        } catch { }
    }

    $header = @{
        DateTime = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        Hostname = [System.Environment]::MachineName
        Username = [System.Environment]::UserName
        OsCaption = $osCaption
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }

    $alertNames = @(
        "Get-DiskAlert", "Get-MemoryAlert", "Get-UptimeAlert", "Get-InternetAlert",
        "Get-OneDriveAlert", "Get-SpoolerAlert", "Get-RebootPendingAlert"
    )
    $alerts = @()
    foreach ($name in $alertNames) {
        $a = script:Get-ReportAlertSafe $name
        if ($a) { $alerts += $a }
    }

    $hardware = script:Collect-HardwareReportData
    $memory = script:Collect-MemoryReportData
    $disk = script:Collect-DiskReportData
    $rdpData = script:Collect-RdpReportData
    $netData = script:Collect-NetworkReportData
    $slowData = script:Collect-SlownessReportData
    $odData = script:Collect-OneDriveReportData
    $prData = script:Collect-PrinterReportData
    $winData = script:Collect-WindowsReportData
    $eventsData = script:Collect-CriticalEventsData
    $startupData = script:Collect-StartupProgramsData
    $defenderData = script:Collect-DefenderReportData

    $wuStatus = "OK"
    if ($eventsData.Events | Where-Object { $_.Event -like "*WindowsUpdateClient*20*" }) {
        $wuStatus = "ATENCAO"
    }

    $health = script:Calculate-HealthScore -Metrics @{
        Disk = $disk
        Memory = $memory
        Network = $netData
        WinUpdate = @{ Status = $wuStatus }
        Events = $eventsData
        Rdp = $rdpData
        OneDrive = $odData
        Printers = $prData
        Defender = $defenderData
    }

    $problems = script:Build-ProblemsFromData -Alerts $alerts -RdpData $rdpData -EventsData $eventsData -MemoryData $memory -DiskData $disk -DefenderData $defenderData
    $recommendations = script:Build-SmartRecommendations -Alerts $alerts -MemoryData $memory -DiskData $disk -EventsData $eventsData -StartupData $startupData -DefenderData $defenderData -Slowness $slowData -RdpData $rdpData

    $criticalCount = @($problems | Where-Object { $_.Status -eq "CRITICO" }).Count
    $atencaoCount = @($problems | Where-Object { $_.Status -eq "ATENCAO" }).Count

    $executiveSummary = if ($health.Score -ge 80) {
        "Maquina em bom estado geral (score $($health.Score)). $($criticalCount) problema(s) critico(s), $($atencaoCount) atencao(oes)."
    } elseif ($health.Score -ge 60) {
        "Maquina requer atencao (score $($health.Score)). Verifique problemas e recomendacoes abaixo."
    } else {
        "Maquina em estado critico (score $($health.Score)). Suporte deve agir com prioridade."
    }

    $supportAction = if ($criticalCount -gt 0 -or $health.Score -lt 60) { "SIM - acao recomendada" } elseif ($atencaoCount -gt 0) { "AVALIAR - problemas de atencao detectados" } else { "NAO - monitoramento de rotina" }

    $report = @{
        Header = $header
        Health = $health
        ExecutiveSummary = $executiveSummary
        SupportAction = $supportAction
        Problems = $problems
        Recommendations = $recommendations
        Hardware = $hardware
        Memory = $memory
        Disk = $disk
        Network = $netData
        Rdp = $rdpData
        OneDrive = $odData
        Printers = $prData
        Windows = $winData
        Events = $eventsData
        Startup = $startupData
        Defender = $defenderData
        Slowness = $slowData
    }

    try {
        $html = script:Render-AtlasSupportHtml -Report $report
        Set-Content -Path $htmlFile -Value $html -Encoding UTF8 -ErrorAction Stop
        if (-not (Test-Path $htmlFile)) {
            throw "Arquivo HTML nao foi criado em $htmlFile"
        }
        Write-Log -Message "Relatorio HTML gerado na Area de Trabalho: $htmlFile" -Level "INFO"
        Write-AtlasSessionLog -Message "Relatorio HTML: $htmlFile" -Level "ACTION"
        Write-Host ""
        Write-Host "Relatorio de suporte gerado com sucesso!" -ForegroundColor Green
        Write-Host "Arquivo: $htmlFile" -ForegroundColor Cyan
        Write-Host ""
        return $htmlFile
    } catch {
        Write-Log -Message "Erro ao gerar relatorio HTML: $_" -Level "ERROR"
        Write-Host "Erro ao gerar relatorio: $_" -ForegroundColor Red
        return $null
    }
}


# ------------------------------------------
# Funcao principal (compatibilidade)

function New-AtlasSupportReport {
    Write-Log -Message "Iniciando geracao de relatorio de suporte" -Level "INFO"

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $repoRoot  = Split-Path $script:_SupportModuleDir -Parent
    $reportsRoot = Join-Path $repoRoot "reports"
    $reportDir   = Join-Path $reportsRoot "atlas_support_$timestamp"

    Write-Host ""
    Write-Host "Gerando relatorio de suporte..." -ForegroundColor Cyan
    Write-Host "Pasta: $reportDir" -ForegroundColor Gray
    Write-Host ""

    try {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    } catch {
        Write-Log -Message "Erro ao criar pasta do relatorio: $_" -Level "ERROR"
        Write-Host "Erro ao criar pasta do relatorio: $_" -ForegroundColor Red
        return
    }

    $sections = [ordered]@{}

    $sections["system"]           = script:Invoke-SupportSection `
        -FilePath  (Join-Path $reportDir "system.txt") `
        -Title     "Informacoes do Sistema" `
        -Collector { script:Build-SystemSection }

    $sections["disk"]             = script:Invoke-SupportSection `
        -FilePath  (Join-Path $reportDir "disk.txt") `
        -Title     "Espaco em Disco" `
        -Collector { script:Build-DiskSection }

    $sections["network"]          = script:Invoke-SupportSection `
        -FilePath  (Join-Path $reportDir "network.txt") `
        -Title     "Rede e Internet" `
        -Collector { script:Build-NetworkSection }

    $sections["onedrive"]         = script:Invoke-SupportSection `
        -FilePath  (Join-Path $reportDir "onedrive.txt") `
        -Title     "OneDrive" `
        -Collector { script:Build-OneDriveSection }

    $sections["printer"]          = script:Invoke-SupportSection `
        -FilePath  (Join-Path $reportDir "printer.txt") `
        -Title     "Impressoras" `
        -Collector { script:Build-PrinterSection }

    $sections["quick-diagnostic"] = script:Invoke-SupportSection `
        -FilePath  (Join-Path $reportDir "quick-diagnostic.txt") `
        -Title     "Diagnostico Rapido" `
        -Collector { script:Build-QuickDiagnosticSection }

    # Logs recentes do Atlas
    Write-Host "  Coletando: Logs recentes do Atlas..." -ForegroundColor Gray
    $logsRoot = Join-Path $repoRoot "logs"
    $logFile  = Join-Path $logsRoot "provisionador.log"
    if (Test-Path $logFile) {
        try {
            $tail   = Get-Content $logFile -Tail 100 -ErrorAction Stop
            $header = "Atlas - Logs Recentes (ultimas 100 linhas)`nGerado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$('=' * 50)`n"
            Set-Content -Path (Join-Path $reportDir "logs.txt") -Value ($header + "`n" + ($tail -join "`n")) -Encoding UTF8
            $sections["logs"] = "ok"
        } catch {
            Set-Content -Path (Join-Path $reportDir "logs.txt") -Value "Erro ao ler logs: $_" -Encoding UTF8
            $sections["logs"] = "error"
        }
    } else {
        Set-Content -Path (Join-Path $reportDir "logs.txt") -Value "Arquivo de log nao encontrado: $logFile" -Encoding UTF8
        $sections["logs"] = "not-found"
    }

    # summary.txt
    Write-Host "  Gerando resumo..." -ForegroundColor Gray
    $summaryLines = @(
        "Atlas - Relatorio de Suporte",
        "Gerado em : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Host      : $([System.Environment]::MachineName)",
        "Usuario   : $([System.Environment]::UserName)",
        "OS        : $([System.Environment]::OSVersion.VersionString)",
        "Pasta     : $reportDir",
        "",
        "Secoes:"
    )
    foreach ($key in $sections.Keys) {
        $icon = if ($sections[$key] -eq "ok") { "[OK]   " } else { "[AVISO]" }
        $summaryLines += "  $icon $key"
    }
    Set-Content -Path (Join-Path $reportDir "summary.txt") -Value ($summaryLines -join "`n") -Encoding UTF8

    # summary.json
    $jsonObj = [ordered]@{
        timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        hostname   = [System.Environment]::MachineName
        username   = [System.Environment]::UserName
        platform   = [System.Environment]::OSVersion.Platform.ToString()
        osVersion  = [System.Environment]::OSVersion.VersionString
        reportPath = $reportDir
        sections   = $sections
    }
    $jsonObj | ConvertTo-Json -Depth 3 |
        Set-Content -Path (Join-Path $reportDir "summary.json") -Encoding UTF8

    Write-Log -Message "Relatorio de suporte gerado: $reportDir" -Level "INFO"

    Write-Host ""
    Write-Host "Relatorio gerado com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Pasta: $reportDir" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Arquivos:" -ForegroundColor Gray
    Get-ChildItem $reportDir | Sort-Object Name | ForEach-Object {
        Write-Host "  $($_.Name)" -ForegroundColor Gray
    }
    Write-Host ""
}
