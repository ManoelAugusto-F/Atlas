function New-SupportEvidenceBundle {

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Coletando Evidencias para Atendimento" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportsBase = Join-Path (Split-Path $PSScriptRoot -Parent) "reports"
    $bundleDir   = Join-Path $reportsBase "Atlas_Evidence_$timestamp"

    try {
        New-Item -ItemType Directory -Path $bundleDir -Force | Out-Null
    } catch {
        Write-Host "Erro ao criar pasta de evidencias: $_" -ForegroundColor Red
        Write-Log -Message "Erro ao criar pasta de evidencias: $_" -Level "ERROR"
        return
    }

    Write-Host "Pasta: $bundleDir" -ForegroundColor DarkGray
    Write-Host ""

    # Funcao auxiliar para capturar saida como texto sem exibir no terminal
    function Capture-Output {
        param([scriptblock]$Block)
        try {
            $output = $( & $Block *>&1 ) | Out-String
            return $output
        } catch {
            return "Erro: $_"
        }
    }

    # --- system.txt ---
    Write-Host "  [1/6] Coletando informacoes do sistema..." -NoNewline
    $sysLines = [System.Collections.Generic.List[string]]::new()
    $sysLines.Add("ATLAS - Evidencias de Suporte")
    $sysLines.Add("Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')")
    $sysLines.Add("=" * 50)
    $sysLines.Add("")
    $sysLines.Add("SISTEMA")
    $sysLines.Add("Hostname    : $([System.Net.Dns]::GetHostName())")
    $sysLines.Add("SO          : $($PSVersionTable.OS)")
    $sysLines.Add("Arquitetura : $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)")
    $sysLines.Add("PowerShell  : $($PSVersionTable.PSVersion)")
    if (Test-IsWindows) {
        $sysLines.Add("Usuario     : $env:USERNAME")
        try {
            $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            $sysLines.Add("Dominio     : $(if ($cs.PartOfDomain) { $cs.Domain } else { 'WORKGROUP' })")
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $sysLines.Add("Windows     : $($os.Caption) (Build $($os.BuildNumber))")
            $uptime = (Get-Date) - $os.LastBootUpTime
            $sysLines.Add("Ultimo boot : $($os.LastBootUpTime.ToString('dd/MM/yyyy HH:mm:ss'))")
            $sysLines.Add(("Uptime      : {0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes))
            $sysLines.Add("Mem Total   : $([math]::Round($os.TotalVisibleMemorySize/1MB, 1)) GB")
            $sysLines.Add("Mem Livre   : $([math]::Round($os.FreePhysicalMemory/1MB, 1)) GB")
        } catch { $sysLines.Add("(detalhes WMI indisponiveis)") }
    } else {
        $sysLines.Add("Usuario     : $env:USER")
        $raw = Get-Content /proc/uptime -ErrorAction SilentlyContinue
        if ($raw) {
            $sec    = [double]($raw.Split(" ")[0])
            $bootDt = (Get-Date).AddSeconds(-$sec)
            $up     = New-TimeSpan -Seconds $sec
            $sysLines.Add("Ultimo boot : $($bootDt.ToString('dd/MM/yyyy HH:mm:ss'))")
            $sysLines.Add(("Uptime      : {0}d {1}h {2}m" -f $up.Days, $up.Hours, $up.Minutes))
        }
        $memInfo = Get-Content /proc/meminfo -ErrorAction SilentlyContinue
        if ($memInfo) {
            $total = ($memInfo | Select-String "^MemTotal").ToString()  -replace "[^0-9]", ""
            $avail = ($memInfo | Select-String "^MemAvailable").ToString() -replace "[^0-9]", ""
            $sysLines.Add("Mem Total   : $([math]::Round([long]$total/1MB,1)) GB")
            $sysLines.Add("Mem Livre   : $([math]::Round([long]$avail/1MB,1)) GB")
        }
    }
    $sysLines | Set-Content "$bundleDir\system.txt" -Encoding UTF8
    Write-Host " OK" -ForegroundColor Green

    # --- network.txt ---
    Write-Host "  [2/6] Coletando informacoes de rede..." -NoNewline
    $netOut = Capture-Output { Get-NetworkInformation }
    $netOut | Set-Content "$bundleDir\network.txt" -Encoding UTF8
    Write-Host " OK" -ForegroundColor Green

    # --- disk.txt ---
    Write-Host "  [3/6] Coletando informacoes de disco..." -NoNewline
    $diskOut = Capture-Output { Get-DiskUsage }
    $diskOut | Set-Content "$bundleDir\disk.txt" -Encoding UTF8
    Write-Host " OK" -ForegroundColor Green

    # --- services.txt ---
    Write-Host "  [4/6] Coletando informacoes de servicos..." -NoNewline
    if (Test-IsWindows) {
        $svcOut = Capture-Output { Test-EssentialWindowsServices }
    } else {
        $svcOut = "Funcao exclusiva do Windows. No Linux, use 'systemctl list-units --state=failed'."
    }
    $svcOut | Set-Content "$bundleDir\services.txt" -Encoding UTF8
    Write-Host " OK" -ForegroundColor Green

    # --- security.txt ---
    Write-Host "  [5/6] Coletando status de seguranca..." -NoNewline
    if (Test-IsWindows) {
        $secOut = Capture-Output { Get-BasicSecurityStatus }
    } else {
        $secOut = "Funcao exclusiva do Windows."
    }
    $secOut | Set-Content "$bundleDir\security.txt" -Encoding UTF8
    Write-Host " OK" -ForegroundColor Green

    # --- summary.json ---
    Write-Host "  [6/6] Gerando summary.json..." -NoNewline
    $summary = [ordered]@{
        hostname    = [System.Net.Dns]::GetHostName()
        os          = $PSVersionTable.OS.ToString()
        psVersion   = $PSVersionTable.PSVersion.ToString()
        arch        = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        platform    = if (Test-IsWindows) { "Windows" } else { "Linux" }
        files       = @("system.txt", "network.txt", "disk.txt", "services.txt", "security.txt")
    }
    $summary | ConvertTo-Json -Depth 3 | Set-Content "$bundleDir\summary.json" -Encoding UTF8
    Write-Host " OK" -ForegroundColor Green

    Write-Host ""
    Write-Host "Evidencias coletadas em:" -ForegroundColor Green
    Write-Host "  $bundleDir" -ForegroundColor Cyan

    Write-Log -Message "New-SupportEvidenceBundle gerado em: $bundleDir" -Level "INFO"
}
