function Get-NetworkInformation {

    Write-Host ""
    Write-Host "Informacoes de rede:" -ForegroundColor Yellow
    Write-Host ""

    if (Test-IsWindows) {
        try {
            $adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.IPAddress -ne "127.0.0.1" }

            foreach ($adapter in $adapters) {
                Write-Host "Interface : $($adapter.InterfaceAlias)"
                Write-Host "IP        : $($adapter.IPAddress)"
                Write-Host "Prefixo   : $($adapter.PrefixLength)"
                Write-Host ""
            }

            $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.ServerAddresses.Count -gt 0 }

            if ($dns) {
                Write-Host "Servidores DNS:"
                foreach ($entry in $dns) {
                    Write-Host "  $($entry.InterfaceAlias): $($entry.ServerAddresses -join ', ')"
                }
            }
        }
        catch {
            Write-Host "Erro ao obter informacoes de rede: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Sistema: Linux"

        $ipCmd = Get-Command ip -ErrorAction SilentlyContinue
        if ($ipCmd) {
            Write-Host ""
            Write-Host "Interfaces de rede:"
            & ip -brief address 2>/dev/null
        }
        else {
            $ifconfigCmd = Get-Command ifconfig -ErrorAction SilentlyContinue
            if ($ifconfigCmd) {
                & ifconfig 2>/dev/null | Select-String -Pattern "inet " | ForEach-Object {
                    Write-Host $_.Line.Trim()
                }
            }
            else {
                Write-Host "Comandos 'ip' e 'ifconfig' nao encontrados." -ForegroundColor DarkGray
            }
        }

        $resolv = "/etc/resolv.conf"
        if (Test-Path $resolv) {
            Write-Host ""
            Write-Host "Servidores DNS (resolv.conf):"
            Get-Content $resolv | Select-String "^nameserver" | ForEach-Object {
                Write-Host "  $($_.Line)"
            }
        }
    }
}

function Test-NetworkConnectivity {

    Write-Host ""
    Write-Host "Testando conectividade de rede:" -ForegroundColor Yellow
    Write-Host ""

    # Teste de ping
    Write-Host "Ping para 8.8.8.8..." -NoNewline
    $ping = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet -ErrorAction SilentlyContinue
    if ($ping) {
        Write-Host " OK" -ForegroundColor Green
    }
    else {
        Write-Host " FALHOU" -ForegroundColor Red
    }

    # Teste de resolucao DNS
    Write-Host "Resolucao DNS para google.com..." -NoNewline
    try {
        $dns = [System.Net.Dns]::GetHostAddresses("google.com")
        if ($dns.Count -gt 0) {
            Write-Host " OK ($($dns[0].IPAddressToString))" -ForegroundColor Green
        }
        else {
            Write-Host " SEM RESULTADO" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host " FALHOU ($_)" -ForegroundColor Red
    }

    Write-Host ""
}
