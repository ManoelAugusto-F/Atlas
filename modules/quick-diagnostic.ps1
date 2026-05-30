# ==========================================
# Atlas — Modulo de Diagnostico Rapido
# ==========================================

# ──────────────────────────────────────────
# Helpers internos
# ──────────────────────────────────────────

function script:IsWindows-Diag {
    return ($IsWindows -or $env:OS -eq 'Windows_NT')
}

# Retorna objeto: @{ Label; Status; Message; Suggestion }
# Status: "OK" | "ATENCAO" | "CRITICO" | "NA"

# ──────────────────────────────────────────
# [1] Disco
# ──────────────────────────────────────────

function Get-DiskAlert {
    try {
        if (script:IsWindows-Diag) {
            $drive = Get-PSDrive -Name C -PSProvider FileSystem -ErrorAction Stop
            $total = $drive.Used + $drive.Free
            if ($total -le 0) { throw "Disco C: sem dados" }
            $pctFree = [math]::Round($drive.Free / $total * 100, 1)
            $pctUsed = 100 - $pctFree
            $freeGB  = [math]::Round($drive.Free  / 1GB, 2)
            $totalGB = [math]::Round($total        / 1GB, 2)
            $label   = "Disco C:"
            $detail  = "${pctFree}% livre (${freeGB}GB / ${totalGB}GB)"
        } else {
            $dfOut = (& df / 2>&1) | Select-Object -Skip 1 | Select-Object -First 1
            if (-not $dfOut) { throw "df sem saida" }
            $cols    = ($dfOut -split '\s+')
            # Formato: Filesystem 1K-blocks Used Available Use% Mounted
            $pctUsed = [double]($cols[4] -replace '%', '')
            $pctFree = [math]::Round(100 - $pctUsed, 1)
            $label   = "Disco /"
            $detail  = "${pctFree}% livre"
        }

        $status = if ($pctFree -lt 10) { "CRITICO" }
                  elseif ($pctFree -lt 15) { "ATENCAO" }
                  else { "OK" }

        $suggestion = if ($status -eq "CRITICO") { "Execute Limpeza Segura (opcao 2) urgentemente — disco critico." }
                      elseif ($status -eq "ATENCAO") { "Execute Limpeza Segura (opcao 2) para liberar espaco." }
                      else { $null }

        return [pscustomobject]@{
            Label      = $label
            Status     = $status
            Message    = "$label $detail"
            Suggestion = $suggestion
        }
    } catch {
        return [pscustomobject]@{
            Label      = "Disco"
            Status     = "ATENCAO"
            Message    = "Disco: nao foi possivel verificar ($_)"
            Suggestion = $null
        }
    }
}

# ──────────────────────────────────────────
# [2] Memoria
# ──────────────────────────────────────────

function Get-MemoryAlert {
    try {
        if (script:IsWindows-Diag) {
            $os      = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $total   = $os.TotalVisibleMemorySize
            $free    = $os.FreePhysicalMemory
            $pctUsed = [math]::Round(($total - $free) / $total * 100, 1)
        } else {
            if (-not (Test-Path /proc/meminfo)) { throw "/proc/meminfo nao encontrado" }
            $rawTotal = (Get-Content /proc/meminfo | Where-Object { $_ -match '^MemTotal:' })     -replace '[^\d]', ''
            $rawFree  = (Get-Content /proc/meminfo | Where-Object { $_ -match '^MemAvailable:' }) -replace '[^\d]', ''
            $total    = [long]$rawTotal
            $free     = [long]$rawFree
            $pctUsed  = [math]::Round(($total - $free) / $total * 100, 1)
        }

        $freeGB  = [math]::Round($free  / 1MB, 2)
        $totalGB = [math]::Round($total / 1MB, 2)
        $status  = if ($pctUsed -gt 90) { "CRITICO" }
                   elseif ($pctUsed -gt 80) { "ATENCAO" }
                   else { "OK" }

        $suggestion = if ($status -eq "CRITICO") { "Memoria critica (${pctUsed}% em uso). Feche programas desnecessarios ou reinicie." }
                      elseif ($status -eq "ATENCAO") { "Memoria alta (${pctUsed}% em uso). Considere fechar programas pesados." }
                      else { $null }

        return [pscustomobject]@{
            Label      = "Memoria"
            Status     = $status
            Message    = "Memoria: ${pctUsed}% em uso (livre: ${freeGB}GB / total: ${totalGB}GB)"
            Suggestion = $suggestion
        }
    } catch {
        return [pscustomobject]@{
            Label      = "Memoria"
            Status     = "ATENCAO"
            Message    = "Memoria: nao foi possivel verificar ($_)"
            Suggestion = $null
        }
    }
}

# ──────────────────────────────────────────
# [3] Uptime
# ──────────────────────────────────────────

function Get-UptimeAlert {
    try {
        if (script:IsWindows-Diag) {
            $os   = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $span = (Get-Date) - $os.LastBootUpTime
        } else {
            if (Test-Path /proc/uptime) {
                $secs = [double]((Get-Content /proc/uptime).Split(' ')[0])
                $span = [TimeSpan]::FromSeconds($secs)
            } else {
                throw "/proc/uptime nao encontrado"
            }
        }

        $days        = [int]$span.TotalDays
        $hrs         = $span.Hours
        $mins        = $span.Minutes
        $detail      = "${days}d ${hrs}h ${mins}m"
        $status      = if ($days -ge 30) { "CRITICO" }
                       elseif ($days -ge 15) { "ATENCAO" }
                       else { "OK" }

        $suggestion = if ($status -eq "CRITICO") { "Computador sem reiniciar ha $days dias. Reinicie em breve para aplicar atualizacoes." }
                      elseif ($status -eq "ATENCAO") { "Computador sem reiniciar ha $days dias. Considere reiniciar." }
                      else { $null }

        return [pscustomobject]@{
            Label      = "Uptime"
            Status     = $status
            Message    = "Uptime: $detail"
            Suggestion = $suggestion
        }
    } catch {
        return [pscustomobject]@{
            Label      = "Uptime"
            Status     = "ATENCAO"
            Message    = "Uptime: nao foi possivel verificar ($_)"
            Suggestion = $null
        }
    }
}

# ──────────────────────────────────────────
# [4] Internet / DNS
# ──────────────────────────────────────────

function Get-InternetAlert {
    $dnsOk = $false
    $tcpOk = $false

    try {
        [System.Net.Dns]::GetHostAddresses("google.com") | Out-Null
        $dnsOk = $true
    } catch { }

    try {
        $tcp  = New-Object System.Net.Sockets.TcpClient
        $conn = $tcp.BeginConnect("google.com", 443, $null, $null)
        $wait = $conn.AsyncWaitHandle.WaitOne(3000, $false)
        if ($wait -and $tcp.Connected) { $tcpOk = $true }
        $tcp.Close()
    } catch { }

    if ($dnsOk -and $tcpOk) {
        return [pscustomobject]@{
            Label      = "Internet"
            Status     = "OK"
            Message    = "Internet: DNS e TCP 443 respondendo"
            Suggestion = $null
        }
    } elseif ($dnsOk) {
        return [pscustomobject]@{
            Label      = "Internet"
            Status     = "ATENCAO"
            Message    = "Internet: DNS ok, mas TCP 443 falhou"
            Suggestion = "Verifique conectividade ou firewall. Use Rede e Internet (opcao 3) para diagnostico completo."
        }
    } else {
        return [pscustomobject]@{
            Label      = "Internet"
            Status     = "ATENCAO"
            Message    = "Internet: sem acesso (DNS e TCP falharam)"
            Suggestion = "Verifique cabos, Wi-Fi ou use Rede e Internet (opcao 3) para diagnostico completo."
        }
    }
}

# ──────────────────────────────────────────
# [5] OneDrive (Windows only)
# ──────────────────────────────────────────

function Get-OneDriveAlert {
    if (-not (script:IsWindows-Diag)) {
        return [pscustomobject]@{
            Label      = "OneDrive"
            Status     = "NA"
            Message    = "OneDrive: N/A (nao aplicavel neste sistema)"
            Suggestion = $null
        }
    }

    $proc = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    if ($proc) {
        return [pscustomobject]@{
            Label      = "OneDrive"
            Status     = "OK"
            Message    = "OneDrive: em execucao (PID $($proc.Id))"
            Suggestion = $null
        }
    } else {
        return [pscustomobject]@{
            Label      = "OneDrive"
            Status     = "ATENCAO"
            Message    = "OneDrive: processo nao encontrado"
            Suggestion = "Verifique OneDrive (opcao 4): reinicie ou redefina o processo."
        }
    }
}

# ──────────────────────────────────────────
# [6] Spooler (Windows only)
# ──────────────────────────────────────────

function Get-SpoolerAlert {
    if (-not (script:IsWindows-Diag)) {
        return [pscustomobject]@{
            Label      = "Spooler"
            Status     = "NA"
            Message    = "Spooler: N/A (nao aplicavel neste sistema)"
            Suggestion = $null
        }
    }

    try {
        $svc = Get-Service -Name Spooler -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            return [pscustomobject]@{
                Label      = "Spooler"
                Status     = "OK"
                Message    = "Spooler: em execucao"
                Suggestion = $null
            }
        } else {
            return [pscustomobject]@{
                Label      = "Spooler"
                Status     = "ATENCAO"
                Message    = "Spooler: parado (Status: $($svc.Status))"
                Suggestion = "Use Impressoras (opcao 5) para reiniciar o servico Spooler."
            }
        }
    } catch {
        return [pscustomobject]@{
            Label      = "Spooler"
            Status     = "ATENCAO"
            Message    = "Spooler: nao foi possivel verificar ($_)"
            Suggestion = $null
        }
    }
}

# ──────────────────────────────────────────
# [7] Reboot pendente (Windows only)
# ──────────────────────────────────────────

function Get-RebootPendingAlert {
    if (-not (script:IsWindows-Diag)) {
        return [pscustomobject]@{
            Label      = "Reboot Pendente"
            Status     = "NA"
            Message    = "Reboot Pendente: N/A (nao aplicavel neste sistema)"
            Suggestion = $null
        }
    }

    $pending = $false
    $reasons = @()

    $checks = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired";  Key = $null },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending";   Key = $null },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager";                                     Key = "PendingFileRenameOperations" }
    )

    foreach ($c in $checks) {
        try {
            if ($null -ne $c.Key) {
                $val = Get-ItemProperty -Path $c.Path -Name $c.Key -ErrorAction Stop
                if ($val.($c.Key)) {
                    $pending = $true
                    $reasons += $c.Path.Split('\')[-1]
                }
            } else {
                if (Test-Path $c.Path) {
                    $pending = $true
                    $reasons += $c.Path.Split('\')[-1]
                }
            }
        } catch { }
    }

    if ($pending) {
        return [pscustomobject]@{
            Label      = "Reboot Pendente"
            Status     = "ATENCAO"
            Message    = "Reboot Pendente: reinicializacao necessaria ($($reasons -join ', '))"
            Suggestion = "Reinicie o computador para finalizar atualizacoes pendentes."
        }
    } else {
        return [pscustomobject]@{
            Label      = "Reboot Pendente"
            Status     = "OK"
            Message    = "Reboot Pendente: nenhuma reinicializacao pendente"
            Suggestion = $null
        }
    }
}

# ──────────────────────────────────────────
# Funcao principal
# ──────────────────────────────────────────

function Invoke-QuickDiagnostic {
    Write-Log -Message "Iniciando diagnostico rapido" -Level "INFO"

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Atlas - Diagnostico Rapido" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Executando verificacoes..." -ForegroundColor Gray
    Write-Host ""

    $results = @(
        (Get-DiskAlert)
        (Get-MemoryAlert)
        (Get-UptimeAlert)
        (Get-InternetAlert)
        (Get-OneDriveAlert)
        (Get-SpoolerAlert)
        (Get-RebootPendingAlert)
    )

    # Calcular status geral
    $overallStatus = "OK"
    foreach ($r in $results) {
        if ($r.Status -eq "CRITICO") { $overallStatus = "CRITICO"; break }
        if ($r.Status -eq "ATENCAO" -and $overallStatus -ne "CRITICO") { $overallStatus = "ATENCAO" }
    }

    Write-Log -Message "Diagnostico concluido — Status geral: $overallStatus" -Level "INFO"

    # Exibir status geral
    $statusColor = switch ($overallStatus) {
        "CRITICO" { "Red" }
        "ATENCAO" { "Yellow" }
        default   { "Green" }
    }
    Write-Host "Status geral: " -NoNewline
    Write-Host $overallStatus -ForegroundColor $statusColor
    Write-Host ""

    # Exibir achados
    Write-Host "Achados:" -ForegroundColor Cyan
    foreach ($r in $results) {
        $color = switch ($r.Status) {
            "CRITICO" { "Red" }
            "ATENCAO" { "Yellow" }
            "NA"      { "DarkGray" }
            default   { "Green" }
        }
        $tag = switch ($r.Status) {
            "CRITICO" { "[CRITICO] " }
            "ATENCAO" { "[ATENCAO] " }
            "NA"      { "[N/A]     " }
            default   { "[OK]      " }
        }
        Write-Host "  $tag$($r.Message)" -ForegroundColor $color
    }

    # Exibir sugestoes
    $suggestions = $results | Where-Object { $_.Suggestion } | Select-Object -ExpandProperty Suggestion
    if ($suggestions.Count -gt 0) {
        Write-Host ""
        Write-Host "Sugestoes:" -ForegroundColor Cyan
        foreach ($s in $suggestions) {
            Write-Host "  - $s" -ForegroundColor Yellow
        }
    }

    Write-Host ""
}
