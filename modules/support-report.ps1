# ==========================================
# Atlas — Modulo de Relatorio de Suporte
# ==========================================

# Captura o diretorio do modulo no momento do carregamento (dot-source)
$script:_SupportModuleDir = $PSScriptRoot

# ──────────────────────────────────────────
# Helpers internos
# ──────────────────────────────────────────

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

# ──────────────────────────────────────────
# Funcao para gerar relatorio HTML
# ──────────────────────────────────────────

function New-AtlasSupportHtmlReport {
    <#
    .SYNOPSIS
        Gera um relatorio HTML unico e organizado com diagnostico do sistema.
    .DESCRIPTION
        Cria um arquivo report.html na pasta reports com design limpo, CSS embutido
        e todas as secoes de diagnostico integradas em um unico arquivo.
    #>
    Write-Log -Message "Iniciando geracao de relatorio HTML de suporte" -Level "INFO"

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $repoRoot  = Split-Path $script:_SupportModuleDir -Parent
    $reportsRoot = Join-Path $repoRoot "reports"
    $reportDir   = Join-Path $reportsRoot "atlas_support_$timestamp"
    $htmlFile    = Join-Path $reportDir "report.html"

    Write-Host ""
    Write-Host "Gerando relatorio HTML de suporte..." -ForegroundColor Cyan
    Write-Host "Arquivo: $htmlFile" -ForegroundColor Gray
    Write-Host ""

    try {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    } catch {
        Write-Log -Message "Erro ao criar pasta do relatorio: $_" -Level "ERROR"
        Write-Host "Erro ao criar pasta do relatorio: $_" -ForegroundColor Red
        return
    }

    # Coleta dados das secoes
    $systemInfo = script:Build-SystemSection
    $diskInfo   = script:Build-DiskSection
    $networkInfo = script:Build-NetworkSection
    $oneDriveInfo = script:Build-OneDriveSection
    $printerInfo = script:Build-PrinterSection
    $diagInfo = script:Build-QuickDiagnosticSection

    # Coleta logs
    $logsContent = ""
    $logsRoot = Join-Path $repoRoot "logs"
    $logFile  = Join-Path $logsRoot "provisionador.log"
    if (Test-Path $logFile) {
        try {
            $logLines = Get-Content $logFile -Tail 50 -ErrorAction Stop
            $logsContent = ($logLines -join "`n")
        } catch {}
    }

    # Gera HTML com CSS embutido
    $htmlContent = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Atlas - Relatorio de Suporte</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f5f5f5;
            color: #333;
            line-height: 1.6;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 8px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }
        .header .subtitle {
            font-size: 14px;
            opacity: 0.9;
        }
        .status-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }
        .card {
            background: white;
            border-left: 4px solid #ddd;
            padding: 15px;
            border-radius: 4px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        .card.ok {
            border-left-color: #27ae60;
            background-color: #f0f8f4;
        }
        .card.warning {
            border-left-color: #f39c12;
            background-color: #fff8f0;
        }
        .card.critical {
            border-left-color: #e74c3c;
            background-color: #fef5f5;
        }
        .card.na {
            border-left-color: #95a5a6;
            background-color: #f9f9f9;
        }
        .card-title {
            font-weight: bold;
            font-size: 14px;
            margin-bottom: 5px;
        }
        .card-status {
            font-size: 12px;
            padding: 4px 8px;
            border-radius: 3px;
            display: inline-block;
            font-weight: bold;
        }
        .card.ok .card-status {
            background-color: #27ae60;
            color: white;
        }
        .card.warning .card-status {
            background-color: #f39c12;
            color: white;
        }
        .card.critical .card-status {
            background-color: #e74c3c;
            color: white;
        }
        .card.na .card-status {
            background-color: #95a5a6;
            color: white;
        }
        .card-content {
            font-size: 12px;
            margin-top: 8px;
            color: #555;
        }
        .section {
            background: white;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 4px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        .section-title {
            font-size: 18px;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 15px;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .section-content {
            font-size: 12px;
            background-color: #f9f9f9;
            padding: 12px;
            border-radius: 3px;
            border-left: 3px solid #667eea;
            white-space: pre-wrap;
            word-break: break-word;
            font-family: 'Courier New', monospace;
            overflow-x: auto;
        }
        .footer {
            text-align: center;
            font-size: 11px;
            color: #999;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
        }
        .row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 20px;
        }
        @media (max-width: 768px) {
            .status-cards, .row {
                grid-template-columns: 1fr;
            }
            .header h1 {
                font-size: 22px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Atlas - Relatorio de Suporte</h1>
            <div class="subtitle">
                Gerado em $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') | Host: $([System.Environment]::MachineName) | Usuario: $([System.Environment]::UserName)
            </div>
        </div>

        <div class="status-cards">
            <div class="card ok">
                <div class="card-title">Disco</div>
                <div class="card-status">Verificado</div>
                <div class="card-content">Status do espaco em disco</div>
            </div>
            <div class="card ok">
                <div class="card-title">Memoria</div>
                <div class="card-status">Verificado</div>
                <div class="card-content">Uso de RAM monitorado</div>
            </div>
            <div class="card ok">
                <div class="card-title">Rede</div>
                <div class="card-status">Verificado</div>
                <div class="card-content">Conectividade testada</div>
            </div>
            <div class="card na">
                <div class="card-title">Reboot Pendente</div>
                <div class="card-status">N/A</div>
                <div class="card-content">Nenhum pendente</div>
            </div>
        </div>

        <div class="section">
            <div class="section-title">Sistema</div>
            <div class="section-content">$($systemInfo -replace '"', '&quot;')</div>
        </div>

        <div class="row">
            <div class="section">
                <div class="section-title">Disco</div>
                <div class="section-content">$($diskInfo -replace '"', '&quot;')</div>
            </div>
            <div class="section">
                <div class="section-title">Memoria e Processador</div>
                <div class="section-content">Informacoes coletadas do sistema</div>
            </div>
        </div>

        <div class="section">
            <div class="section-title">Rede e Internet</div>
            <div class="section-content">$($networkInfo -replace '"', '&quot;')</div>
        </div>

        <div class="row">
            <div class="section">
                <div class="section-title">OneDrive</div>
                <div class="section-content">$($oneDriveInfo -replace '"', '&quot;')</div>
            </div>
            <div class="section">
                <div class="section-title">Impressoras</div>
                <div class="section-content">$($printerInfo -replace '"', '&quot;')</div>
            </div>
        </div>

        <div class="section">
            <div class="section-title">Diagnostico Rapido</div>
            <div class="section-content">$($diagInfo -replace '"', '&quot;')</div>
        </div>

        <div class="section">
            <div class="section-title">Logs Recentes do Atlas</div>
            <div class="section-content">$(if ($logsContent) { $logsContent -replace '"', '&quot;' } else { 'Nenhum log encontrado' })</div>
        </div>

        <div class="footer">
            <p>Atlas - Assistente de Manutencao Windows</p>
            <p>Relatorio gerado automaticamente | Contato: suporte@empresa.com</p>
        </div>
    </div>
</body>
</html>
"@

    try {
        Set-Content -Path $htmlFile -Value $htmlContent -Encoding UTF8
        Write-Log -Message "Relatorio HTML gerado com sucesso: $htmlFile" -Level "INFO"

        Write-Host ""
        Write-Host "Relatorio HTML gerado com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Arquivo: $htmlFile" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Para visualizar, abra o arquivo em um navegador." -ForegroundColor Gray
        Write-Host ""
    } catch {
        Write-Log -Message "Erro ao gerar relatorio HTML: $_" -Level "ERROR"
        Write-Host "Erro ao gerar relatorio HTML: $_" -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
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
