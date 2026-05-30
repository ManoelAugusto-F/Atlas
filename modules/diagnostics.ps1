# ==========================================================================
# diagnostics.ps1
# Diagnostico corporativo de conectividade de rede
# ==========================================================================

# ---------------------------------------------------------------------------
# Helper privado: testa conectividade TCP com timeout
# ---------------------------------------------------------------------------
function Test-TcpPort {
    param(
        [string]$TargetHost,
        [int]$Port,
        [int]$TimeoutMs = 2000
    )
    try {
        $tcp    = [System.Net.Sockets.TcpClient]::new()
        $result = $tcp.BeginConnect($TargetHost, $Port, $null, $null)
        $ok     = $result.AsyncWaitHandle.WaitOne($TimeoutMs) -and $tcp.Connected
        $tcp.Close()
        return $ok
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
function Test-GatewayConnectivity {
    <#
    .SYNOPSIS
        Identifica e testa conectividade com o gateway padrao via ping.
    .OUTPUTS
        Array de PSCustomObject: Categoria, Teste, Resultado, Detalhes
    #>

    Write-Host ""
    Write-Host "[ GATEWAY ]" -ForegroundColor Yellow

    $results   = [System.Collections.Generic.List[PSCustomObject]]::new()
    $gatewayIp = $null

    if (Test-IsWindows) {
        try {
            $gw        = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop |
                Select-Object -First 1
            $gatewayIp = $gw.NextHop
        } catch {
            Write-Log -Message "Erro ao obter gateway (Get-NetRoute): $_" -Level "WARN"
        }
    } else {
        $ipCmd = Get-Command ip -ErrorAction SilentlyContinue
        if ($ipCmd) {
            $gwLine = & ip route show default 2>/dev/null | Select-Object -First 1
            if ($gwLine -match "via\s+(\S+)") { $gatewayIp = $Matches[1] }
        }
    }

    if ($gatewayIp) {
        Write-Host ("  Gateway detectado : {0}" -f $gatewayIp)
        Write-Host ("  Ping {0} ... " -f $gatewayIp) -NoNewline

        $ok  = Test-Connection -ComputerName $gatewayIp -Count 2 -Quiet -ErrorAction SilentlyContinue
        $res = if ($ok) { "OK" } else { "FALHOU" }
        Write-Host $res -ForegroundColor $(if ($ok) { "Green" } else { "Red" })

        $results.Add([PSCustomObject]@{
            Categoria = "Gateway"
            Teste     = "Ping $gatewayIp"
            Resultado = $res
            Detalhes  = "Gateway padrao"
        })
    } else {
        Write-Host "  Gateway nao identificado." -ForegroundColor DarkGray
        $results.Add([PSCustomObject]@{
            Categoria = "Gateway"
            Teste     = "Ping gateway"
            Resultado = "N/A"
            Detalhes  = "Gateway nao encontrado"
        })
    }

    Write-Log -Message "Test-GatewayConnectivity executado" -Level "INFO"
    return $results.ToArray()
}

# ---------------------------------------------------------------------------
function Test-DnsResolution {
    <#
    .SYNOPSIS
        Testa os servidores DNS configurados (porta 53 TCP) e resolucao de nomes.
    .OUTPUTS
        Array de PSCustomObject: Categoria, Teste, Resultado, Detalhes
    #>

    Write-Host ""
    Write-Host "[ DNS ]" -ForegroundColor Yellow

    $results    = [System.Collections.Generic.List[PSCustomObject]]::new()
    $dnsServers = @()

    if (Test-IsWindows) {
        try {
            $dnsServers = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.ServerAddresses.Count -gt 0 } |
                ForEach-Object { $_.ServerAddresses }) | Select-Object -Unique
        } catch {
            Write-Log -Message "Erro ao obter servidores DNS: $_" -Level "WARN"
        }
    } else {
        $resolv = Get-Content /etc/resolv.conf -ErrorAction SilentlyContinue
        if ($resolv) {
            $dnsServers = $resolv | Select-String "^nameserver\s+(\S+)" | ForEach-Object {
                $_.Matches[0].Groups[1].Value
            }
        }
    }

    # Teste de porta 53 (TCP) em cada servidor DNS configurado
    if ($dnsServers.Count -gt 0) {
        foreach ($srv in $dnsServers | Select-Object -First 3) {
            Write-Host ("  DNS {0} porta 53 ... " -f $srv) -NoNewline
            $ok  = Test-TcpPort -TargetHost $srv -Port 53 -TimeoutMs 1500
            $res = if ($ok) { "OK" } else { "fechado/filtrado" }
            Write-Host $res -ForegroundColor $(if ($ok) { "Green" } else { "DarkGray" })
            $results.Add([PSCustomObject]@{
                Categoria = "DNS"
                Teste     = "TCP 53 em $srv"
                Resultado = $res
                Detalhes  = "Servidor DNS configurado"
            })
        }
    } else {
        Write-Host "  Nenhum servidor DNS identificado." -ForegroundColor DarkGray
    }

    # Resolucao de nomes
    $hosts = @("google.com", "microsoft.com")
    foreach ($h in $hosts) {
        Write-Host ("  Resolucao {0} ... " -f $h) -NoNewline
        try {
            $addrs = [System.Net.Dns]::GetHostAddresses($h)
            $ip    = $addrs | Where-Object { $_.AddressFamily -eq "InterNetwork" } |
                Select-Object -First 1
            $detail = if ($ip) { $ip.IPAddressToString } else { $addrs[0].IPAddressToString }
            Write-Host "OK ($detail)" -ForegroundColor Green
            $results.Add([PSCustomObject]@{
                Categoria = "DNS"
                Teste     = "Resolucao $h"
                Resultado = "OK"
                Detalhes  = $detail
            })
        } catch {
            Write-Host "FALHOU" -ForegroundColor Red
            $results.Add([PSCustomObject]@{
                Categoria = "DNS"
                Teste     = "Resolucao $h"
                Resultado = "FALHOU"
                Detalhes  = $_.Exception.Message
            })
        }
    }

    Write-Log -Message "Test-DnsResolution executado. Servidores: $($dnsServers -join ', ')" -Level "INFO"
    return $results.ToArray()
}

# ---------------------------------------------------------------------------
function Test-InternetConnectivity {
    <#
    .SYNOPSIS
        Testa conectividade com servidores publicos via ping (8.8.8.8 e 1.1.1.1).
    .OUTPUTS
        Array de PSCustomObject: Categoria, Teste, Resultado, Detalhes
    #>

    Write-Host ""
    Write-Host "[ INTERNET ]" -ForegroundColor Yellow

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $targets = @(
        @{ Host = "8.8.8.8";  Label = "8.8.8.8  (Google DNS)" },
        @{ Host = "1.1.1.1";  Label = "1.1.1.1  (Cloudflare)" }
    )

    foreach ($t in $targets) {
        Write-Host ("  Ping {0} ... " -f $t.Label) -NoNewline
        $ok  = Test-Connection -ComputerName $t.Host -Count 2 -Quiet -ErrorAction SilentlyContinue
        $res = if ($ok) { "OK" } else { "FALHOU" }
        Write-Host $res -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
        $results.Add([PSCustomObject]@{
            Categoria = "Internet"
            Teste     = "Ping $($t.Host)"
            Resultado = $res
            Detalhes  = $t.Label
        })
    }

    Write-Log -Message "Test-InternetConnectivity executado" -Level "INFO"
    return $results.ToArray()
}

# ---------------------------------------------------------------------------
function Test-HttpsConnectivity {
    <#
    .SYNOPSIS
        Testa conectividade HTTPS (TCP porta 443) com google.com e microsoft.com.
    .OUTPUTS
        Array de PSCustomObject: Categoria, Teste, Resultado, Detalhes
    #>

    Write-Host ""
    Write-Host "[ HTTPS ]" -ForegroundColor Yellow

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $targets = @(
        @{ Host = "google.com";    Label = "google.com" },
        @{ Host = "microsoft.com"; Label = "microsoft.com" }
    )

    foreach ($t in $targets) {
        Write-Host ("  TCP 443 {0} ... " -f $t.Label) -NoNewline
        $ok  = Test-TcpPort -TargetHost $t.Host -Port 443 -TimeoutMs 3000
        $res = if ($ok) { "OK" } else { "FALHOU" }
        Write-Host $res -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
        $results.Add([PSCustomObject]@{
            Categoria = "HTTPS"
            Teste     = "TCP 443 $($t.Host)"
            Resultado = $res
            Detalhes  = ""
        })
    }

    Write-Log -Message "Test-HttpsConnectivity executado" -Level "INFO"
    return $results.ToArray()
}

# ---------------------------------------------------------------------------
function Test-DomainConnectivity {
    <#
    .SYNOPSIS
        Se a maquina estiver em dominio, testa LDAP (389), Kerberos (88) e DNS (53)
        no controlador de dominio. Exclusivo do Windows.
    .OUTPUTS
        Array de PSCustomObject: Categoria, Teste, Resultado, Detalhes
    #>

    Write-Host ""
    Write-Host "[ DOMINIO ]" -ForegroundColor Yellow

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    if (-not (Test-IsWindows)) {
        Write-Host "  Teste de dominio exclusivo do Windows." -ForegroundColor DarkGray
        $results.Add([PSCustomObject]@{
            Categoria = "Dominio"
            Teste     = "Verificacao de dominio"
            Resultado = "N/A"
            Detalhes  = "Exclusivo Windows"
        })
        Write-Log -Message "Test-DomainConnectivity chamado no Linux (sem acao)" -Level "INFO"
        return $results.ToArray()
    }

    $parteDominio = $false
    $domainName   = $null

    try {
        $cs           = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $parteDominio = $cs.PartOfDomain
        $domainName   = $cs.Domain
    } catch {
        Write-Host "  Nao foi possivel verificar dominio." -ForegroundColor DarkGray
        Write-Log -Message "Erro ao verificar dominio: $_" -Level "WARN"
        return $results.ToArray()
    }

    if (-not $parteDominio) {
        Write-Host "  Maquina nao esta em dominio (WORKGROUP)." -ForegroundColor DarkGray
        $results.Add([PSCustomObject]@{
            Categoria = "Dominio"
            Teste     = "Membro de dominio"
            Resultado = "N/A"
            Detalhes  = "Maquina em WORKGROUP"
        })
        Write-Log -Message "Test-DomainConnectivity: maquina em workgroup" -Level "INFO"
        return $results.ToArray()
    }

    Write-Host ("  Dominio detectado : {0}" -f $domainName)

    # Identificar controlador de dominio
    $dcHost = $null
    if ($env:LOGONSERVER) {
        $dcHost = $env:LOGONSERVER.TrimStart('\')
    }
    if (-not $dcHost -or $dcHost -eq "") {
        $dcHost = $domainName  # fallback para o nome do dominio
    }

    Write-Host ("  Controlador       : {0}" -f $dcHost)

    $dcTests = @(
        @{ Port = 389; Label = "LDAP      (389)"; Service = "LDAP" },
        @{ Port = 88;  Label = "Kerberos  (88) "; Service = "Kerberos" },
        @{ Port = 53;  Label = "DNS       (53) "; Service = "DNS" }
    )

    foreach ($dt in $dcTests) {
        Write-Host ("  {0} em {1} ... " -f $dt.Label, $dcHost) -NoNewline
        $ok  = Test-TcpPort -TargetHost $dcHost -Port $dt.Port -TimeoutMs 2000
        $res = if ($ok) { "OK" } else { "FALHOU" }
        Write-Host $res -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
        $results.Add([PSCustomObject]@{
            Categoria = "Dominio"
            Teste     = "$($dt.Service) TCP $($dt.Port) em $dcHost"
            Resultado = $res
            Detalhes  = $domainName
        })
    }

    Write-Log -Message "Test-DomainConnectivity executado. DC: $dcHost Dominio: $domainName" -Level "INFO"
    return $results.ToArray()
}

# ---------------------------------------------------------------------------
function Invoke-CorporateDiagnostic {
    <#
    .SYNOPSIS
        Executa diagnostico corporativo completo e exporta reports/network-diagnostic.txt.
    #>

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Diagnostico Corporativo de Rede" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # Executar todos os testes e coletar resultados
    $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($r in (Test-GatewayConnectivity))   { $allResults.Add($r) }
    foreach ($r in (Test-DnsResolution))          { $allResults.Add($r) }
    foreach ($r in (Test-InternetConnectivity))   { $allResults.Add($r) }
    foreach ($r in (Test-HttpsConnectivity))      { $allResults.Add($r) }
    foreach ($r in (Test-DomainConnectivity))     { $allResults.Add($r) }

    # Resumo no terminal
    $total    = $allResults.Count
    $ok       = ($allResults | Where-Object { $_.Resultado -eq "OK" }).Count
    $falhou   = ($allResults | Where-Object { $_.Resultado -eq "FALHOU" }).Count

    Write-Host ""
    Write-Host "[ RESUMO ]" -ForegroundColor Yellow
    $corResumo = if ($falhou -eq 0) { "Green" } elseif ($falhou -le 2) { "Yellow" } else { "Red" }
    Write-Host ("  Total: {0}  OK: {1}  Falhou: {2}" -f $total, $ok, $falhou) -ForegroundColor $corResumo

    # Exportar relatório TXT
    $reportsDir = Join-Path (Split-Path $PSScriptRoot -Parent) "reports"
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    $reportPath = Join-Path $reportsDir "network-diagnostic.txt"

    $lines = [System.Collections.Generic.List[string]]::new()
    $sep   = "=" * 50

    $lines.Add("ATLAS — Diagnostico Corporativo de Rede")
    $lines.Add("Gerado em : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')")
    $lines.Add("Hostname  : $([System.Net.Dns]::GetHostName())")
    $platVal = if (Test-IsWindows) { "Windows" } else { "Linux" }
    $lines.Add("Plataforma: $platVal")
    $lines.Add($sep)

    $categories = $allResults | Select-Object -ExpandProperty Categoria -Unique
    foreach ($cat in $categories) {
        $lines.Add("")
        $lines.Add("[ $($cat.ToUpper()) ]")
        $catItems = $allResults | Where-Object { $_.Categoria -eq $cat }
        foreach ($item in $catItems) {
            $detail = if ($item.Detalhes -ne "") { " ($($item.Detalhes))" } else { "" }
            $lines.Add(("  {0,-38} {1}{2}" -f $item.Teste, $item.Resultado, $detail))
        }
    }

    $lines.Add("")
    $lines.Add($sep)
    $lines.Add("RESUMO")
    $lines.Add("Total de testes : $total")
    $lines.Add("OK              : $ok")
    $lines.Add("Falhou          : $falhou")

    $lines | Set-Content $reportPath -Encoding UTF8

    Write-Host ""
    Write-Host "Relatorio exportado:" -ForegroundColor Green
    Write-Host "  $reportPath" -ForegroundColor Cyan
    Write-Host ""

    Write-Log -Message "Invoke-CorporateDiagnostic concluido. OK:$ok Falhou:$falhou Relatorio:$reportPath" -Level "INFO"
}
