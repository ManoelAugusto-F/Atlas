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

function script:Build-ProblemsFromAlerts {
    param(
        [array]$Alerts,
        [hashtable]$RdpData
    )
    $problems = @()
    foreach ($a in $Alerts) {
        if ($a.Status -eq "OK" -or $a.Status -eq "NA") { continue }
        $impact = switch ($a.Status) {
            "CRITICO" { "Alto - pode impedir uso normal do computador" }
            default   { "Medio - pode causar lentidao ou falhas pontuais" }
        }
        $action = if ($a.Suggestion) { $a.Suggestion } else { "Verifique o menu correspondente no Atlas." }
        $problems += [PSCustomObject]@{
            Status = $a.Status
            Description = $a.Message
            Impact = $impact
            Action = $action
        }
    }
    if ($RdpData.Status -eq "ATENCAO") {
        $problems += [PSCustomObject]@{
            Status = "ATENCAO"
            Description = "RDP: $($RdpData.Detail)"
            Impact = "Medio - acesso remoto pode falhar"
            Action = "Verifique TermService e firewall RDP (porta 3389)."
        }
    }
    if ($problems.Count -eq 0) {
        $problems += [PSCustomObject]@{
            Status = "OK"
            Description = "Nenhum problema critico ou de atencao detectado nos checks automaticos."
            Impact = "Baixo"
            Action = "Manter monitoramento periodico com este relatorio."
        }
    }
    return $problems
}

function script:Build-RecommendationsList {
    param([array]$Alerts, [hashtable]$Slowness, [hashtable]$RdpData)
    $recs = [System.Collections.ArrayList]@()
    foreach ($a in $Alerts) {
        if ($a.Suggestion) { [void]$recs.Add($a.Suggestion) }
    }
    if ($Slowness.Recommendation -and $Slowness.Recommendation -ne "Nenhuma recomendacao automatica.") {
        [void]$recs.Add($Slowness.Recommendation)
    }
    if ($RdpData.Status -eq "ATENCAO") {
        [void]$recs.Add("RDP indisponivel: verifique TermService e regras de firewall para porta 3389.")
    }
    $unique = $recs | Select-Object -Unique
    if ($unique.Count -eq 0) {
        return @("Sistema dentro dos parametros esperados. Gere novo relatorio apos qualquer alteracao.")
    }
    return @($unique)
}

function script:Render-HtmlTableRows {
    param([array]$Rows, [string[]]$Columns)
    $html = ""
    foreach ($row in $Rows) {
        $html += "<tr>"
        foreach ($col in $Columns) {
            $val = $row.$col
            if ($null -eq $val) { $val = "" }
            $html += "<td>" + (script:Escape-HtmlText ([string]$val)) + "</td>"
        }
        $html += "</tr>`n"
    }
    return $html
}

function script:Render-AtlasSupportHtml {
    param([hashtable]$Report)

    $h = $Report.Header
    $cards = $Report.Cards
    $problems = $Report.Problems
    $slow = $Report.Slowness
    $net = $Report.Network
    $rdp = $Report.Rdp
    $od = $Report.OneDrive
    $pr = $Report.Printers
    $win = $Report.Windows
    $recs = $Report.Recommendations

    $cardHtml = ""
    foreach ($c in $cards) {
        $suffix = script:Get-StatusCssSuffix $c.Status
        $cardHtml += @"
        <div class="card card-$suffix">
            <div class="card-label">$(script:Escape-HtmlText $c.Label)</div>
            <div class="card-status">$(script:Escape-HtmlText $c.Status)</div>
            <div class="card-detail">$(script:Escape-HtmlText $c.Detail)</div>
        </div>
"@
    }

    $problemRows = ""
    foreach ($p in $problems) {
        $suffix = script:Get-StatusCssSuffix $p.Status
        $problemRows += @"
        <tr class="row-$suffix">
            <td><span class="badge badge-$suffix">$(script:Escape-HtmlText $p.Status)</span></td>
            <td>$(script:Escape-HtmlText $p.Description)</td>
            <td>$(script:Escape-HtmlText $p.Impact)</td>
            <td>$(script:Escape-HtmlText $p.Action)</td>
        </tr>
"@
    }

    $topMemRows = ""
    foreach ($proc in $slow.TopMem) {
        $topMemRows += "<tr><td>$(script:Escape-HtmlText $proc.Name)</td><td>$($proc.MemMB) MB</td></tr>`n"
    }
    if (-not $topMemRows) { $topMemRows = "<tr><td colspan='2'>N/A</td></tr>" }

    $topCpuRows = ""
    foreach ($proc in $slow.TopCpu) {
        $topCpuRows += "<tr><td>$(script:Escape-HtmlText $proc.Name)</td><td>$($proc.CPUs)</td></tr>`n"
    }
    if (-not $topCpuRows) { $topCpuRows = "<tr><td colspan='2'>N/A (indisponivel)</td></tr>" }

    $netLines = ($net.Lines | ForEach-Object { script:Escape-HtmlText $_ }) -join "<br/>"

    $recList = ""
    $i = 1
    foreach ($r in $recs) {
        $recList += "<li><strong>$i.</strong> $(script:Escape-HtmlText $r)</li>`n"
        $i++
    }

    $sysEv = ($win.SystemEvents | ForEach-Object { "<li>$(script:Escape-HtmlText $_)</li>" }) -join "`n"
    if (-not $sysEv) { $sysEv = "<li>Nenhum evento ou N/A</li>" }
    $appEv = ($win.AppEvents | ForEach-Object { "<li>$(script:Escape-HtmlText $_)</li>" }) -join "`n"
    if (-not $appEv) { $appEv = "<li>Nenhum evento ou N/A</li>" }

    $printerRows = ""
    foreach ($row in $pr.PrinterRows) {
        $def = if ($row.Default) { "Sim" } else { "Nao" }
        $printerRows += "<tr><td>$(script:Escape-HtmlText $row.Name)</td><td>$def</td><td>$(script:Escape-HtmlText ([string]$row.Status))</td><td>$(script:Escape-HtmlText ([string]$row.Shared))</td></tr>`n"
    }
    if (-not $printerRows) { $printerRows = "<tr><td colspan='4'>N/A</td></tr>" }

    $odLines = ($od.Lines | ForEach-Object { script:Escape-HtmlText $_ }) -join "<br/>"
    $rdpLines = ($rdp.Lines | ForEach-Object { script:Escape-HtmlText $_ }) -join "<br/>"

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
        .wrap { max-width: 1100px; margin: 0 auto; padding: 24px 20px 40px; }
        .header { background: linear-gradient(135deg, #3b5bdb 0%, #364fc7 100%); color: #fff; padding: 28px 32px; border-radius: 10px; margin-bottom: 28px; box-shadow: 0 4px 14px rgba(0,0,0,0.12); }
        .header h1 { font-size: 26px; margin-bottom: 12px; font-weight: 600; }
        .meta { font-size: 14px; opacity: 0.95; line-height: 1.8; }
        .section { background: #fff; padding: 24px 28px; margin-bottom: 24px; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.06); }
        .section h2 { font-size: 18px; color: #364fc7; margin-bottom: 18px; padding-bottom: 10px; border-bottom: 2px solid #e7ebf3; }
        .cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 14px; }
        .card { padding: 14px 16px; border-radius: 8px; border-left: 4px solid #adb5bd; background: #f8f9fa; }
        .card-ok { border-left-color: #2f9e44; background: #ebfbee; }
        .card-atencao { border-left-color: #f08c00; background: #fff9db; }
        .card-critico { border-left-color: #e03131; background: #fff5f5; }
        .card-na { border-left-color: #868e96; background: #f1f3f5; }
        .card-label { font-size: 12px; text-transform: uppercase; color: #495057; letter-spacing: 0.04em; }
        .card-status { font-size: 20px; font-weight: 700; margin: 6px 0; }
        .card-detail { font-size: 13px; color: #495057; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; margin-top: 8px; }
        th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid #e9ecef; }
        th { background: #f1f3f5; font-weight: 600; color: #495057; }
        tr:hover td { background: #f8f9fa; }
        .badge { display: inline-block; padding: 3px 8px; border-radius: 4px; font-size: 11px; font-weight: 700; }
        .badge-ok { background: #d3f9d8; color: #2b8a3e; }
        .badge-atencao { background: #ffec99; color: #e67700; }
        .badge-critico { background: #ffc9c9; color: #c92a2a; }
        .badge-na { background: #e9ecef; color: #495057; }
        .detail-block { font-size: 14px; margin-bottom: 14px; }
        .detail-block strong { display: block; margin-bottom: 4px; color: #364fc7; }
        ul { margin: 8px 0 8px 20px; font-size: 13px; }
        ul li { margin-bottom: 6px; }
        .reco-list { list-style: none; margin: 0; padding: 0; }
        .reco-list li { padding: 10px 14px; margin-bottom: 8px; background: #e7f5ff; border-left: 3px solid #1c7ed6; border-radius: 4px; }
        .footer { text-align: center; font-size: 12px; color: #868e96; margin-top: 20px; padding-top: 16px; }
        .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        @media (max-width: 768px) { .two-col { grid-template-columns: 1fr; } .cards { grid-template-columns: 1fr; } }
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
        <h2>Resumo executivo</h2>
        <div class="cards">$cardHtml</div>
    </div>

    <div class="section">
        <h2>Problemas encontrados</h2>
        <table>
            <thead><tr><th>Status</th><th>Descricao</th><th>Impacto</th><th>Acao recomendada</th></tr></thead>
            <tbody>$problemRows</tbody>
        </table>
    </div>

    <div class="section">
        <h2>Diagnostico de lentidao</h2>
        <div class="detail-block"><strong>Uso de memoria</strong> $(script:Escape-HtmlText $slow.MemText)</div>
        <div class="detail-block"><strong>Disco livre</strong> $(script:Escape-HtmlText $slow.DiskText)</div>
        <div class="detail-block"><strong>Uptime</strong> $(script:Escape-HtmlText $slow.UptimeText)</div>
        <div class="detail-block"><strong>Recomendacao automatica</strong> $(script:Escape-HtmlText $slow.Recommendation)</div>
        <div class="two-col">
            <div>
                <strong>Top 10 processos por memoria</strong>
                <table><thead><tr><th>Processo</th><th>Memoria</th></tr></thead><tbody>$topMemRows</tbody></table>
            </div>
            <div>
                <strong>Top 10 processos por CPU (quando disponivel)</strong>
                <table><thead><tr><th>Processo</th><th>CPU (s)</th></tr></thead><tbody>$topCpuRows</tbody></table>
            </div>
        </div>
    </div>

    <div class="section">
        <h2>Rede e internet</h2>
        <div class="detail-block"><strong>IP principal</strong> $(script:Escape-HtmlText $net.PrimaryIp)</div>
        <div class="detail-block"><strong>Gateway</strong> $(script:Escape-HtmlText $net.Gateway)</div>
        <div class="detail-block"><strong>DNS configurado</strong> $(script:Escape-HtmlText $net.DnsConfig)</div>
        <div class="detail-block"><strong>Testes</strong><br/>$netLines</div>
    </div>

    <div class="section">
        <h2>RDP</h2>
        <div class="detail-block"><strong>Status final</strong> <span class="badge badge-$(script:Get-StatusCssSuffix $rdp.Status)">$(script:Escape-HtmlText $rdp.Status)</span></div>
        <div class="detail-block">$rdpLines</div>
    </div>

    <div class="section">
        <h2>OneDrive</h2>
        <div class="detail-block"><strong>Status final</strong> <span class="badge badge-$(script:Get-StatusCssSuffix $od.Status)">$(script:Escape-HtmlText $od.Status)</span></div>
        <div class="detail-block">$odLines</div>
    </div>

    <div class="section">
        <h2>Impressoras</h2>
        <div class="detail-block"><strong>Spooler</strong> $(script:Escape-HtmlText $pr.SpoolerStatus) | <strong>Padrao</strong> $(script:Escape-HtmlText $pr.DefaultPrinter) | <strong>Fila</strong> $(script:Escape-HtmlText $pr.QueueInfo)</div>
        <table>
            <thead><tr><th>Nome</th><th>Padrao</th><th>Status</th><th>Compartilhada</th></tr></thead>
            <tbody>$printerRows</tbody>
        </table>
    </div>

    <div class="section">
        <h2>Windows</h2>
        <div class="detail-block"><strong>Reboot pendente</strong> $(script:Escape-HtmlText $win.RebootPending)</div>
        <div class="detail-block"><strong>Windows Update (hotfix)</strong> $(script:Escape-HtmlText $win.WindowsUpdate)</div>
        <div class="two-col">
            <div><strong>System - ultimos 10 erros/criticos (2 dias)</strong><ul>$sysEv</ul></div>
            <div><strong>Application - ultimos 10 erros/criticos (2 dias)</strong><ul>$appEv</ul></div>
        </div>
    </div>

    <div class="section">
        <h2>Acoes recomendadas</h2>
        <ul class="reco-list">$recList</ul>
    </div>

    <div class="footer">
        <p>Atlas v0.2.2 - Assistente de Manutencao Windows</p>
        <p>Relatorio gerado automaticamente em $(script:Escape-HtmlText $h.DateTime)</p>
    </div>
</div>
</body>
</html>
"@
}

function New-AtlasSupportHtmlReport {
    Write-Log -Message "Iniciando geracao de relatorio HTML" -Level "INFO"

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

    $rdpData = script:Collect-RdpReportData
    $netData = script:Collect-NetworkReportData
    $slowData = script:Collect-SlownessReportData
    $odData = script:Collect-OneDriveReportData
    $prData = script:Collect-PrinterReportData
    $winData = script:Collect-WindowsReportData

    $overall = script:Get-OverallStatusFromAlerts $alerts
    $diskAlert = $alerts | Where-Object { $_.Label -like "Disco*" } | Select-Object -First 1
    $memAlert = $alerts | Where-Object { $_.Label -eq "Memoria" } | Select-Object -First 1
    $netAlert = $alerts | Where-Object { $_.Label -eq "Internet" } | Select-Object -First 1
    $odAlert = $alerts | Where-Object { $_.Label -eq "OneDrive" } | Select-Object -First 1
    $spAlert = $alerts | Where-Object { $_.Label -eq "Spooler" } | Select-Object -First 1
    $rbAlert = $alerts | Where-Object { $_.Label -eq "Reboot Pendente" } | Select-Object -First 1

    $printerCardStatus = if ($prData.Status -ne "NA") { $prData.Status } elseif ($spAlert) { $spAlert.Status } else { "NA" }

    $cards = @(
        @{ Label = "Status geral"; Status = $overall; Detail = "Consolidado dos diagnosticos" }
        @{ Label = "Disco"; Status = $(if ($diskAlert) { $diskAlert.Status } else { "NA" }); Detail = $(if ($diskAlert) { $diskAlert.Message } else { "N/A" }) }
        @{ Label = "Memoria"; Status = $(if ($memAlert) { $memAlert.Status } else { "NA" }); Detail = $(if ($memAlert) { $memAlert.Message } else { "N/A" }) }
        @{ Label = "Internet/DNS"; Status = $netData.Status; Detail = $(if ($netAlert) { $netAlert.Message } else { "Testes de conectividade" }) }
        @{ Label = "OneDrive"; Status = $(if ($odData.Status -ne "NA") { $odData.Status } elseif ($odAlert) { $odAlert.Status } else { "NA" }); Detail = $(if ($odAlert) { $odAlert.Message } else { $odData.ProcessRunning }) }
        @{ Label = "Impressoras"; Status = $printerCardStatus; Detail = "Spooler: $($prData.SpoolerStatus)" }
        @{ Label = "Reboot pendente"; Status = $(if ($rbAlert) { $rbAlert.Status } else { "NA" }); Detail = $(if ($rbAlert) { $rbAlert.Message } else { "N/A" }) }
        @{ Label = "RDP"; Status = $rdpData.Status; Detail = $rdpData.Detail }
    )

    $problems = script:Build-ProblemsFromAlerts -Alerts $alerts -RdpData $rdpData
    $recommendations = script:Build-RecommendationsList -Alerts $alerts -Slowness $slowData -RdpData $rdpData

    $report = @{
        Header = $header
        Cards = $cards
        Problems = $problems
        Slowness = $slowData
        Network = $netData
        Rdp = $rdpData
        OneDrive = $odData
        Printers = $prData
        Windows = $winData
        Recommendations = $recommendations
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
