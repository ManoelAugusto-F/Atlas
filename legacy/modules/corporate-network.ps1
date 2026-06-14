# Dominio interno a testar (deixar vazio para pular)
$InternalDomainToTest = ""

function Test-CorporateNetworkHealth {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Verificacao de Saude de Rede" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # --- Gateway padrao ---
    Write-Host "[ GATEWAY PADRAO ]" -ForegroundColor Yellow
    $gatewayIp = $null
    if (Test-IsWindows) {
        try {
            $gw = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop | Select-Object -First 1
            $gatewayIp = $gw.NextHop
        } catch {}
    } else {
        $routeCmd = Get-Command ip -ErrorAction SilentlyContinue
        if ($routeCmd) {
            $gwLine = & ip route show default 2>/dev/null | Select-Object -First 1
            if ($gwLine -match "via\s+(\S+)") { $gatewayIp = $Matches[1] }
        }
    }

    if ($gatewayIp) {
        Write-Host ("  Gateway : {0}" -f $gatewayIp) -NoNewline
        $pingGw = Test-Connection -ComputerName $gatewayIp -Count 1 -Quiet -ErrorAction SilentlyContinue
        Write-Host (" -> {0}" -f $(if ($pingGw) { "OK" } else { "SEM RESPOSTA" })) -ForegroundColor $(if ($pingGw) { "Green" } else { "Yellow" })
    } else {
        Write-Host "  Gateway nao identificado." -ForegroundColor DarkGray
    }

    # --- DNS e conectividade externa ---
    Write-Host ""
    Write-Host "[ CONECTIVIDADE EXTERNA ]" -ForegroundColor Yellow

    $targets = @(
        @{ Label = "Ping 8.8.8.8  "; Host = "8.8.8.8";  Mode = "ping" },
        @{ Label = "Ping 1.1.1.1  "; Host = "1.1.1.1";  Mode = "ping" },
        @{ Label = "DNS google.com"; Host = "google.com"; Mode = "dns"  },
        @{ Label = "TCP 80  google"; Host = "google.com"; Port = 80;  Mode = "tcp" },
        @{ Label = "TCP 443 google"; Host = "google.com"; Port = 443; Mode = "tcp" }
    )

    foreach ($t in $targets) {
        Write-Host ("  {0} ... " -f $t.Label) -NoNewline
        $ok = $false
        try {
            switch ($t.Mode) {
                "ping" {
                    $ok = Test-Connection -ComputerName $t.Host -Count 1 -Quiet -ErrorAction SilentlyContinue
                }
                "dns" {
                    $resolved = [System.Net.Dns]::GetHostAddresses($t.Host)
                    $ok = $resolved.Count -gt 0
                }
                "tcp" {
                    $tcp    = [System.Net.Sockets.TcpClient]::new()
                    $result = $tcp.BeginConnect($t.Host, $t.Port, $null, $null)
                    $ok     = $result.AsyncWaitHandle.WaitOne(2000) -and $tcp.Connected
                    $tcp.Close()
                }
            }
        } catch { $ok = $false }
        Write-Host $(if ($ok) { "OK" } else { "FALHOU" }) -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
    }

    # --- DNS local (porta 53) ---
    Write-Host ""
    Write-Host "[ DNS CONFIGURADO ]" -ForegroundColor Yellow
    $dnsServers = @()
    if (Test-IsWindows) {
        try {
            $dnsServers = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.ServerAddresses.Count -gt 0 } |
                Select-Object -First 1).ServerAddresses
        } catch {}
    } else {
        $resolv = Get-Content /etc/resolv.conf -ErrorAction SilentlyContinue
        if ($resolv) {
            $dnsServers = $resolv | Select-String "^nameserver\s+(\S+)" | ForEach-Object {
                $_.Matches[0].Groups[1].Value
            }
        }
    }

    if ($dnsServers.Count -gt 0) {
        foreach ($srv in $dnsServers | Select-Object -First 2) {
            Write-Host ("  TCP 53 em {0} ... " -f $srv) -NoNewline
            try {
                $tcp    = [System.Net.Sockets.TcpClient]::new()
                $result = $tcp.BeginConnect($srv, 53, $null, $null)
                $ok     = $result.AsyncWaitHandle.WaitOne(1000) -and $tcp.Connected
                $tcp.Close()
                Write-Host $(if ($ok) { "OK" } else { "fechado/filtrado" }) -ForegroundColor $(if ($ok) { "Green" } else { "DarkGray" })
            } catch {
                Write-Host "inacessivel" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "  Nenhum servidor DNS identificado." -ForegroundColor DarkGray
    }

    # --- Dominio interno (opcional) ---
    if ($script:InternalDomainToTest -ne "") {
        Write-Host ""
        Write-Host "[ DOMINIO INTERNO: $($script:InternalDomainToTest) ]" -ForegroundColor Yellow
        Write-Host ("  Resolucao DNS ... ") -NoNewline
        try {
            $r = [System.Net.Dns]::GetHostAddresses($script:InternalDomainToTest)
            Write-Host "OK ($($r[0].IPAddressToString))" -ForegroundColor Green
        } catch {
            Write-Host "FALHOU" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Log -Message "Test-CorporateNetworkHealth executado" -Level "INFO"
}
