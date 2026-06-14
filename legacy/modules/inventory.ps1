# ==========================================================================
# inventory.ps1
# Coleta de inventario de sistema, hardware, rede e usuario
# ==========================================================================

function Get-SystemInventory {
    <#
    .SYNOPSIS
        Coleta informacoes de identificacao do sistema operacional.
    .OUTPUTS
        PSCustomObject com campos: Hostname, OS, Build, Arquitetura, PowerShell
    #>

    Write-Host ""
    Write-Host "[ SISTEMA ]" -ForegroundColor Yellow

    $hostname = [System.Net.Dns]::GetHostName()
    $os       = $PSVersionTable.OS.ToString()
    $arch     = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    $psVer    = $PSVersionTable.PSVersion.ToString()
    $build    = "N/A"
    $edition  = "N/A"

    if (Test-IsWindows) {
        try {
            $osObj   = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $os      = $osObj.Caption
            $build   = $osObj.BuildNumber
            $edition = $osObj.OSArchitecture
        } catch {
            Write-Log -Message "Erro em Get-SystemInventory (Win32_OperatingSystem): $_" -Level "WARN"
        }
    } else {
        $kernel = & uname -r 2>$null
        if ($kernel) { $build = $kernel }
    }

    Write-Host ("  Hostname    : {0}" -f $hostname)
    Write-Host ("  Sistema     : {0}" -f $os)
    Write-Host ("  Build       : {0}" -f $build)
    Write-Host ("  Arquitetura : {0}" -f $arch)
    Write-Host ("  PowerShell  : {0}" -f $psVer)

    Write-Log -Message "Get-SystemInventory executado" -Level "INFO"

    return [PSCustomObject]@{
        Hostname    = $hostname
        Sistema     = $os
        Build       = $build
        Arquitetura = $arch
        PowerShell  = $psVer
    }
}

# --------------------------------------------------------------------------

function Get-HardwareInventory {
    <#
    .SYNOPSIS
        Coleta informacoes de hardware: CPU, RAM, discos, BIOS, fabricante e modelo.
    .OUTPUTS
        PSCustomObject com campos: Fabricante, Modelo, CPU, CpuNucleos, CpuLogicos,
        RamTotalGB, Discos, Bios, BiosVersao, BiosData
    #>

    Write-Host ""
    Write-Host "[ HARDWARE ]" -ForegroundColor Yellow

    $fabricante  = "N/A"
    $modelo      = "N/A"
    $cpuNome     = "N/A"
    $cpuNucleos  = "N/A"
    $cpuLogicos  = "N/A"
    $cpuFreqMHz  = "N/A"
    $ramTotalGB  = "N/A"
    $biosNome    = "N/A"
    $biosVersao  = "N/A"
    $biosData    = "N/A"
    $diskList    = [System.Collections.Generic.List[PSCustomObject]]::new()

    if (Test-IsWindows) {

        # Fabricante e modelo
        try {
            $cs         = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            $fabricante = $cs.Manufacturer
            $modelo     = $cs.Model
            $ramTotalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        } catch {
            Write-Log -Message "Erro em Get-HardwareInventory (Win32_ComputerSystem): $_" -Level "WARN"
        }

        # CPU
        try {
            $cpu        = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
            $cpuNome    = $cpu.Name.Trim()
            $cpuNucleos = $cpu.NumberOfCores
            $cpuLogicos = $cpu.NumberOfLogicalProcessors
            $cpuFreqMHz = $cpu.MaxClockSpeed
        } catch {
            Write-Log -Message "Erro em Get-HardwareInventory (Win32_Processor): $_" -Level "WARN"
        }

        # Discos
        try {
            $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
            foreach ($d in $disks) {
                $totalGB = [math]::Round($d.Size / 1GB, 1)
                $freeGB  = [math]::Round($d.FreeSpace / 1GB, 1)
                $usedGB  = [math]::Round(($d.Size - $d.FreeSpace) / 1GB, 1)
                $pct     = if ($d.Size -gt 0) { [math]::Round(($d.Size - $d.FreeSpace) / $d.Size * 100, 1) } else { 0 }
                $diskList.Add([PSCustomObject]@{
                    Drive   = $d.DeviceID
                    TotalGB = $totalGB
                    UsadoGB = $usedGB
                    LivreGB = $freeGB
                    Pct     = $pct
                })
            }
        } catch {
            Write-Log -Message "Erro em Get-HardwareInventory (Win32_LogicalDisk): $_" -Level "WARN"
        }

        # BIOS
        try {
            $bios       = Get-CimInstance Win32_BIOS -ErrorAction Stop
            $biosNome   = $bios.Manufacturer
            $biosVersao = $bios.SMBIOSBIOSVersion
            $biosData   = if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('dd/MM/yyyy') } else { "N/A" }
        } catch {
            Write-Log -Message "Erro em Get-HardwareInventory (Win32_BIOS): $_" -Level "WARN"
        }

    } else {
        # Linux — /proc/cpuinfo e /proc/meminfo
        $cpuInfo = Get-Content /proc/cpuinfo -ErrorAction SilentlyContinue
        if ($cpuInfo) {
            $cpuNome    = ($cpuInfo | Select-String "model name" | Select-Object -First 1).ToString() -replace ".*:\s*", ""
            $cpuLogicos = ($cpuInfo | Select-String "^processor" | Measure-Object).Count
        }

        $memInfo = Get-Content /proc/meminfo -ErrorAction SilentlyContinue
        if ($memInfo) {
            $total      = ($memInfo | Select-String "^MemTotal").ToString() -replace "[^0-9]", ""
            $ramTotalGB = [math]::Round([long]$total / 1MB, 1)
        }

        $dmidecode = Get-Command dmidecode -ErrorAction SilentlyContinue
        if ($dmidecode) {
            $sysInfo = & dmidecode -t system 2>/dev/null
            if ($sysInfo) {
                $mfr   = $sysInfo | Select-String "Manufacturer:" | Select-Object -First 1
                $mdl   = $sysInfo | Select-String "Product Name:" | Select-Object -First 1
                if ($mfr) { $fabricante = $mfr.ToString() -replace ".*:\s*", "" }
                if ($mdl) { $modelo     = $mdl.ToString() -replace ".*:\s*", "" }
            }
        }

        $dfCmd = Get-Command df -ErrorAction SilentlyContinue
        if ($dfCmd) {
            $dfLines = & df -h 2>/dev/null | Select-String "^/"
            foreach ($line in $dfLines) {
                $parts = ($line.Line -split '\s+')
                if ($parts.Count -ge 6) {
                    $diskList.Add([PSCustomObject]@{
                        Drive   = $parts[5]
                        TotalGB = $parts[1]
                        UsadoGB = $parts[2]
                        LivreGB = $parts[3]
                        Pct     = $parts[4]
                    })
                }
            }
        }
    }

    Write-Host ("  Fabricante  : {0}" -f $fabricante)
    Write-Host ("  Modelo      : {0}" -f $modelo)
    Write-Host ("  CPU         : {0}" -f $cpuNome)
    if ($cpuNucleos -ne "N/A") { Write-Host ("  Nucleos     : {0} fisicos / {1} logicos" -f $cpuNucleos, $cpuLogicos) }
    if ($cpuFreqMHz -ne "N/A") { Write-Host ("  Frequencia  : {0} MHz" -f $cpuFreqMHz) }
    Write-Host ("  RAM Total   : {0} GB" -f $ramTotalGB)

    if ($diskList.Count -gt 0) {
        Write-Host "  Discos:"
        foreach ($d in $diskList) {
            Write-Host ("    {0}  Total:{1}  Usado:{2}  Livre:{3}  ({4}%)" -f `
                $d.Drive, $d.TotalGB, $d.UsadoGB, $d.LivreGB, $d.Pct)
        }
    }

    Write-Host ("  BIOS        : {0} v{1} ({2})" -f $biosNome, $biosVersao, $biosData)

    Write-Log -Message "Get-HardwareInventory executado" -Level "INFO"

    return [PSCustomObject]@{
        Fabricante  = $fabricante
        Modelo      = $modelo
        CPU         = $cpuNome
        CpuNucleos  = $cpuNucleos
        CpuLogicos  = $cpuLogicos
        CpuFreqMHz  = $cpuFreqMHz
        RamTotalGB  = $ramTotalGB
        Discos      = $diskList.ToArray()
        BiosFabricante = $biosNome
        BiosVersao  = $biosVersao
        BiosData    = $biosData
    }
}

# --------------------------------------------------------------------------

function Get-NetworkInventory {
    <#
    .SYNOPSIS
        Coleta informacoes de rede: IPs, gateway e servidores DNS.
    .OUTPUTS
        PSCustomObject com campos: Interfaces, Gateway, DNS
    #>

    Write-Host ""
    Write-Host "[ REDE ]" -ForegroundColor Yellow

    $interfaceList = [System.Collections.Generic.List[PSCustomObject]]::new()
    $gateway       = "N/A"
    $dnsServers    = @()

    if (Test-IsWindows) {
        try {
            $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" }
            foreach ($a in $addrs) {
                $interfaceList.Add([PSCustomObject]@{
                    Interface = $a.InterfaceAlias
                    IP        = $a.IPAddress
                    Prefixo   = $a.PrefixLength
                })
            }
        } catch {
            Write-Log -Message "Erro em Get-NetworkInventory (Get-NetIPAddress): $_" -Level "WARN"
        }

        try {
            $gw      = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop | Select-Object -First 1
            $gateway = $gw.NextHop
        } catch {
            Write-Log -Message "Erro em Get-NetworkInventory (Get-NetRoute): $_" -Level "WARN"
        }

        try {
            $dnsObj     = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.ServerAddresses.Count -gt 0 }
            $dnsServers = $dnsObj | ForEach-Object { $_.ServerAddresses } | Select-Object -Unique
        } catch {
            Write-Log -Message "Erro em Get-NetworkInventory (Get-DnsClientServerAddress): $_" -Level "WARN"
        }

    } else {
        $ipCmd = Get-Command ip -ErrorAction SilentlyContinue
        if ($ipCmd) {
            $lines = & ip -brief address 2>/dev/null | Where-Object { $_ -notmatch "^lo" }
            foreach ($line in $lines) {
                $parts = $line -split '\s+'
                $interfaceList.Add([PSCustomObject]@{
                    Interface = if ($parts.Count -gt 0) { $parts[0] } else { "?" }
                    IP        = if ($parts.Count -gt 2) { $parts[2] } else { "?" }
                    Prefixo   = ""
                })
            }

            $gwLine = & ip route show default 2>/dev/null | Select-Object -First 1
            if ($gwLine -match "via\s+(\S+)") { $gateway = $Matches[1] }
        }

        $resolv = Get-Content /etc/resolv.conf -ErrorAction SilentlyContinue
        if ($resolv) {
            $dnsServers = $resolv | Select-String "^nameserver\s+(\S+)" | ForEach-Object {
                $_.Matches[0].Groups[1].Value
            }
        }
    }

    foreach ($i in $interfaceList) {
        Write-Host ("  {0,-20} IP: {1}" -f $i.Interface, $i.IP)
    }
    Write-Host ("  Gateway     : {0}" -f $gateway)
    Write-Host ("  DNS         : {0}" -f ($dnsServers -join ", "))

    Write-Log -Message "Get-NetworkInventory executado" -Level "INFO"

    return [PSCustomObject]@{
        Interfaces = $interfaceList.ToArray()
        Gateway    = $gateway
        DNS        = $dnsServers
    }
}

# --------------------------------------------------------------------------

function Get-UserInventory {
    <#
    .SYNOPSIS
        Coleta informacoes do usuario e ambiente de dominio.
    .OUTPUTS
        PSCustomObject com campos: Usuario, Dominio, ParteDominio, Computador
    #>

    Write-Host ""
    Write-Host "[ USUARIO ]" -ForegroundColor Yellow

    $usuario      = if (Test-IsWindows) { $env:USERNAME } else { $env:USER }
    $dominio      = "N/A"
    $parteDominio = $false
    $computador   = [System.Net.Dns]::GetHostName()

    if (Test-IsWindows) {
        try {
            $cs           = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            $parteDominio = $cs.PartOfDomain
            $dominio      = if ($parteDominio) { $cs.Domain } else { "WORKGROUP: $($cs.Workgroup)" }
        } catch {
            Write-Log -Message "Erro em Get-UserInventory (Win32_ComputerSystem): $_" -Level "WARN"
        }
    } else {
        $idCmd = Get-Command id -ErrorAction SilentlyContinue
        if ($idCmd) {
            $groupsRaw = & id 2>/dev/null
            if ($groupsRaw) { $dominio = $groupsRaw }
        }
    }

    Write-Host ("  Usuario     : {0}" -f $usuario)
    Write-Host ("  Computador  : {0}" -f $computador)
    Write-Host ("  Dominio     : {0}" -f $dominio)

    Write-Log -Message "Get-UserInventory executado" -Level "INFO"

    return [PSCustomObject]@{
        Usuario      = $usuario
        Computador   = $computador
        Dominio      = $dominio
        ParteDominio = $parteDominio
    }
}

# --------------------------------------------------------------------------

function Invoke-FullInventory {
    <#
    .SYNOPSIS
        Executa inventario completo e exporta para reports/inventory.txt e reports/inventory.json.
    #>

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Inventario Completo — Atlas" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # Coleta dados (exibe + retorna objetos)
    $sysData  = Get-SystemInventory
    $hwData   = Get-HardwareInventory
    $netData  = Get-NetworkInventory
    $usrData  = Get-UserInventory

    Write-Host ""

    # Diretorio de reports
    $reportsDir = Join-Path (Split-Path $PSScriptRoot -Parent) "reports"
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }

    $txtPath  = Join-Path $reportsDir "inventory.txt"
    $jsonPath = Join-Path $reportsDir "inventory.json"

    # --- Exportar TXT ---
    $lines = [System.Collections.Generic.List[string]]::new()
    $sep   = "=" * 50

    $lines.Add("ATLAS — Inventario Completo")
    $lines.Add("Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')")
    $lines.Add($sep)

    $lines.Add("")
    $lines.Add("[ SISTEMA ]")
    $lines.Add("Hostname    : $($sysData.Hostname)")
    $lines.Add("Sistema     : $($sysData.Sistema)")
    $lines.Add("Build       : $($sysData.Build)")
    $lines.Add("Arquitetura : $($sysData.Arquitetura)")
    $lines.Add("PowerShell  : $($sysData.PowerShell)")

    $lines.Add("")
    $lines.Add("[ USUARIO ]")
    $lines.Add("Usuario     : $($usrData.Usuario)")
    $lines.Add("Computador  : $($usrData.Computador)")
    $lines.Add("Dominio     : $($usrData.Dominio)")

    $lines.Add("")
    $lines.Add("[ HARDWARE ]")
    $lines.Add("Fabricante  : $($hwData.Fabricante)")
    $lines.Add("Modelo      : $($hwData.Modelo)")
    $lines.Add("CPU         : $($hwData.CPU)")
    $lines.Add("Nucleos     : $($hwData.CpuNucleos) fisicos / $($hwData.CpuLogicos) logicos")
    $lines.Add("RAM Total   : $($hwData.RamTotalGB) GB")
    foreach ($d in $hwData.Discos) {
        $lines.Add("Disco       : $($d.Drive) Total:$($d.TotalGB) Usado:$($d.UsadoGB) Livre:$($d.LivreGB)")
    }
    $lines.Add("BIOS        : $($hwData.BiosFabricante) v$($hwData.BiosVersao) ($($hwData.BiosData))")

    $lines.Add("")
    $lines.Add("[ REDE ]")
    foreach ($i in $netData.Interfaces) {
        $lines.Add("Interface   : $($i.Interface) — $($i.IP)")
    }
    $lines.Add("Gateway     : $($netData.Gateway)")
    $lines.Add("DNS         : $($netData.DNS -join ', ')")

    $lines | Set-Content $txtPath -Encoding UTF8

    # --- Exportar JSON ---
    $inventory = [ordered]@{
        geradoEm  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        plataforma = if (Test-IsWindows) { "Windows" } else { "Linux" }
        sistema   = $sysData
        usuario   = $usrData
        hardware  = $hwData
        rede      = $netData
    }

    $inventory | ConvertTo-Json -Depth 5 | Set-Content $jsonPath -Encoding UTF8

    Write-Host "Inventario exportado:" -ForegroundColor Green
    Write-Host "  TXT  : $txtPath" -ForegroundColor Cyan
    Write-Host "  JSON : $jsonPath" -ForegroundColor Cyan
    Write-Host ""

    Write-Log -Message "Invoke-FullInventory concluido. TXT: $txtPath | JSON: $jsonPath" -Level "INFO"
}
