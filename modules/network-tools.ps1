# ==========================================
# Atlas — Modulo de Rede e Internet
# ==========================================

# ──────────────────────────────────────────
# Helper interno de confirmacao
# ──────────────────────────────────────────

function script:Confirm-NetworkAction {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $resp = Read-Host "Confirmar? (s/N)"
    return ($resp -match '^[sS]$')
}

function script:Test-IsWindowsNetwork {
    return ($IsWindows -or $env:OS -eq 'Windows_NT')
}

# ──────────────────────────────────────────
# [1] Testar internet
# ──────────────────────────────────────────

function Test-InternetConnectionBasic {
    Write-Log -Message "Testando conexao com a internet" -Level "INFO"
    Write-Host ""
    Write-Host "Testando conexao com a internet..." -ForegroundColor Cyan

    # Resolucao DNS
    try {
        [System.Net.Dns]::GetHostAddresses("google.com") | Out-Null
        Write-Host "  [OK] Resolucao DNS de google.com" -ForegroundColor Green
    } catch {
        Write-Host "  [FALHA] Resolucao DNS de google.com: $_" -ForegroundColor Red
    }

    # TCP 443
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $conn = $tcp.BeginConnect("google.com", 443, $null, $null)
        $wait = $conn.AsyncWaitHandle.WaitOne(3000, $false)
        if ($wait -and $tcp.Connected) {
            Write-Host "  [OK] TCP 443 para google.com" -ForegroundColor Green
        } else {
            Write-Host "  [FALHA] TCP 443 para google.com (timeout)" -ForegroundColor Red
        }
        $tcp.Close()
    } catch {
        Write-Host "  [FALHA] TCP 443 para google.com: $_" -ForegroundColor Red
    }

    # Ping 8.8.8.8
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $result = $ping.Send("8.8.8.8", 3000)
        if ($result.Status -eq 'Success') {
            Write-Host ("  [OK] Ping 8.8.8.8 ({0} ms)" -f $result.RoundtripTime) -ForegroundColor Green
        } else {
            Write-Host "  [FALHA] Ping 8.8.8.8: $($result.Status)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [FALHA] Ping 8.8.8.8: $_" -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [2] Testar DNS
# ──────────────────────────────────────────

function Test-DnsBasic {
    Write-Log -Message "Testando DNS" -Level "INFO"
    Write-Host ""
    Write-Host "Testando resolucao DNS..." -ForegroundColor Cyan

    # DNS configurado
    try {
        if (script:Test-IsWindowsNetwork) {
            $dnsServers = Get-DnsClientServerAddress -ErrorAction SilentlyContinue |
                Where-Object { $_.AddressFamily -eq 2 -and $_.ServerAddresses.Count -gt 0 } |
                Select-Object -ExpandProperty ServerAddresses
            if ($dnsServers) {
                Write-Host ("  DNS configurado: {0}" -f ($dnsServers -join ', ')) -ForegroundColor Gray
            }
        } else {
            $resolvConf = "/etc/resolv.conf"
            if (Test-Path $resolvConf) {
                $nameservers = Get-Content $resolvConf | Where-Object { $_ -match '^nameserver' }
                $nameservers | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            }
        }
    } catch {
        Write-Host "  (nao foi possivel obter DNS configurado)" -ForegroundColor Gray
    }

    # Resolucao de hosts
    foreach ($dnsTarget in @("google.com", "microsoft.com")) {
        try {
            $ips = [System.Net.Dns]::GetHostAddresses($dnsTarget) | Select-Object -First 2 | ForEach-Object { $_.IPAddressToString }
            Write-Host ("  [OK] {0} -> {1}" -f $dnsTarget, ($ips -join ', ')) -ForegroundColor Green
        } catch {
            Write-Host ("  [FALHA] {0}: {1}" -f $dnsTarget, $_) -ForegroundColor Red
        }
    }
}

# ──────────────────────────────────────────
# [3] Mostrar configuracao de rede
# ──────────────────────────────────────────

function Get-NetworkConfigBasic {
    Write-Log -Message "Exibindo configuracao de rede" -Level "INFO"
    Write-Host ""

    if (script:Test-IsWindowsNetwork) {
        Write-Host "Configuracao de rede (ipconfig /all):" -ForegroundColor Cyan
        try {
            & ipconfig /all
        } catch {
            Write-Log -Message "Erro ao executar ipconfig: $_" -Level "ERROR"
            Write-Host "Erro ao obter configuracao de rede." -ForegroundColor Red
        }
    } else {
        Write-Host "Enderecos de rede (ip addr):" -ForegroundColor Cyan
        try { & ip addr } catch { Write-Host "  ip addr indisponivel." -ForegroundColor Gray }

        Write-Host ""
        Write-Host "Rotas (ip route):" -ForegroundColor Cyan
        try { & ip route } catch { Write-Host "  ip route indisponivel." -ForegroundColor Gray }

        Write-Host ""
        Write-Host "DNS (/etc/resolv.conf):" -ForegroundColor Cyan
        try {
            if (Test-Path "/etc/resolv.conf") {
                Get-Content "/etc/resolv.conf" | Write-Host
            } else {
                Write-Host "  /etc/resolv.conf nao encontrado." -ForegroundColor Gray
            }
        } catch { Write-Host "  Erro ao ler resolv.conf." -ForegroundColor Gray }
    }
}

# ──────────────────────────────────────────
# [4] Limpar cache DNS
# ──────────────────────────────────────────

function Clear-DnsCacheSafe {
    Write-Log -Message "Iniciando limpeza do cache DNS" -Level "INFO"

    if (-not (script:Test-IsWindowsNetwork)) {
        Write-Host ""
        Write-Host "Flush de cache DNS e focado em Windows." -ForegroundColor Yellow
        Write-Host "No Linux, reinicie o servico de DNS local (systemd-resolved, dnsmasq, etc.) manualmente se necessario."
        return
    }

    Write-Host ""
    Write-Host "Esta acao executa: ipconfig /flushdns" -ForegroundColor Cyan

    if (-not (script:Confirm-NetworkAction "Limpar cache DNS?")) {
        Write-Log -Message "Flush DNS cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        $output = & ipconfig /flushdns 2>&1
        Write-Host $output -ForegroundColor Green
        Write-Log -Message "Cache DNS limpo com sucesso" -Level "INFO"
    } catch {
        Write-Log -Message "Erro ao limpar cache DNS: $_" -Level "ERROR"
        Write-Host "Erro ao limpar cache DNS." -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [5] Renovar IP
# ──────────────────────────────────────────

function Update-IpAddressLeaseSafe {
    Write-Log -Message "Iniciando renovacao de IP" -Level "INFO"

    if (-not (script:Test-IsWindowsNetwork)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Esta acao executa: ipconfig /release e ipconfig /renew" -ForegroundColor Cyan
    Write-Host "AVISO: a conexao de rede pode cair temporariamente durante o processo." -ForegroundColor Yellow

    if (-not (script:Confirm-NetworkAction "Renovar endereco IP?")) {
        Write-Log -Message "Renovacao de IP cancelada pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "Liberando IP..." -ForegroundColor Gray
        & ipconfig /release 2>&1 | Out-Null
        Write-Host "Renovando IP..." -ForegroundColor Gray
        $output = & ipconfig /renew 2>&1
        Write-Host $output
        Write-Log -Message "IP renovado com sucesso" -Level "INFO"
        Write-Host "IP renovado." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Rede" -Acao "Renovacao IP" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao renovar IP: $_" -Level "ERROR"
        Write-Host "Erro durante a renovacao de IP." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Rede" -Acao "Renovacao IP" -Resultado "Falha"
    }
}

# ──────────────────────────────────────────
# [6] Reset Winsock
# ──────────────────────────────────────────

function Reset-WinsockSafe {
    Write-Log -Message "Iniciando reset do Winsock" -Level "INFO"

    if (-not (script:Test-IsWindowsNetwork)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Esta acao executa: netsh winsock reset" -ForegroundColor Cyan
    Write-Host "AVISO: sera necessario reiniciar o computador apos esta operacao." -ForegroundColor Yellow

    if (-not (script:Confirm-NetworkAction "Resetar Winsock?")) {
        Write-Log -Message "Reset Winsock cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        $output = & netsh winsock reset 2>&1
        Write-Host $output
        Write-Log -Message "Winsock resetado. Reinicializacao necessaria." -Level "INFO"
        Write-Host ""
        Write-Host "Winsock resetado. Reinicie o computador para concluir." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Rede" -Acao "Reset Winsock" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao resetar Winsock: $_" -Level "ERROR"
        Write-Host "Erro ao resetar Winsock." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Rede" -Acao "Reset Winsock" -Resultado "Falha"
    }
}

# ──────────────────────────────────────────
# [7] Reset TCP/IP
# ──────────────────────────────────────────

function Reset-TcpIpSafe {
    Write-Log -Message "Iniciando reset do TCP/IP" -Level "INFO"

    if (-not (script:Test-IsWindowsNetwork)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Esta acao executa: netsh int ip reset" -ForegroundColor Cyan
    Write-Host "AVISO: sera necessario reiniciar o computador apos esta operacao." -ForegroundColor Yellow

    if (-not (script:Confirm-NetworkAction "Resetar pilha TCP/IP?")) {
        Write-Log -Message "Reset TCP/IP cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        $output = & netsh int ip reset 2>&1
        Write-Host $output
        Write-Log -Message "TCP/IP resetado. Reinicializacao necessaria." -Level "INFO"
        Write-Host ""
        Write-Host "TCP/IP resetado. Reinicie o computador para concluir." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Rede" -Acao "Reset TCP/IP" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao resetar TCP/IP: $_" -Level "ERROR"
        Write-Host "Erro ao resetar TCP/IP." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Rede" -Acao "Reset TCP/IP" -Resultado "Falha"
    }
}

# ──────────────────────────────────────────
# Menu de rede
# ──────────────────────────────────────────

function Show-NetworkMenu {
    $netRunning = $true

    while ($netRunning) {
        Show-AtlasHeader -Title "Rede e Internet"

        Show-AtlasCompactOption -Number "1" -Name "Testar internet"
        Show-AtlasCompactOption -Number "2" -Name "Testar DNS"
        Show-AtlasCompactOption -Number "3" -Name "Configuracao de rede"
        Show-AtlasCompactOption -Number "4" -Name "Limpar cache DNS"
        Show-AtlasCompactOption -Number "5" -Name "Renovar IP"
        Show-AtlasCompactOption -Number "6" -Name "Reset Winsock"
        Show-AtlasCompactOption -Number "7" -Name "Reset TCP/IP"

        Show-AtlasBackOption
        $opt = Read-AtlasMenuChoice

        switch ($opt) {
            "1" { Test-InternetConnectionBasic; Wait-UserInput }
            "2" { Test-DnsBasic;                Wait-UserInput }
            "3" { Get-NetworkConfigBasic;        Wait-UserInput }
            "4" { Clear-DnsCacheSafe;            Wait-UserInput }
            "5" { Update-IpAddressLeaseSafe;      Wait-UserInput }
            "6" { Reset-WinsockSafe;             Wait-UserInput }
            "7" { Reset-TcpIpSafe;               Wait-UserInput }
            "0" {
                Write-Log -Message "Saindo do menu de rede" -Level "INFO"
                $netRunning = $false
            }
            default {
                Write-Log -Message "Opcao invalida no menu de rede: $opt" -Level "WARN"
                Write-AtlasWarning "Opcao invalida."
                Wait-UserInput
            }
        }
    }
}
