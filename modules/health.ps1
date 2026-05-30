# ==========================================================================
# health.ps1
# Saude do Windows: SFC, DISM, Defender, Updates, Servicos, Reboot
# ==========================================================================

# ---------------------------------------------------------------------------
# Helper privado: verifica privilegios de administrador
# ---------------------------------------------------------------------------
function Test-IsAdmin {
    if (-not (Test-IsWindows)) { return $false }
    try {
        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
function Test-SfcHealth {
    <#
    .SYNOPSIS
        Verifica integridade dos arquivos do sistema via sfc /verifyonly (somente leitura).
    .OUTPUTS
        Hashtable com Status (string da saida do SFC)
    #>

    Write-Host ""
    Write-Host "[ SFC - Verificar Integridade ]" -ForegroundColor Yellow

    if (-not (Test-IsWindows)) {
        Write-Host "  Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Test-SfcHealth chamado no Linux (sem acao)" -Level "INFO"
        return @{ Status = "N/A (Linux)" }
    }

    Write-Host "  Executando: sfc /verifyonly ..." -ForegroundColor Cyan
    Write-Log -Message "Test-SfcHealth iniciado" -Level "INFO"

    $output = "Erro ao executar"
    try {
        $lines  = & sfc /verifyonly 2>&1
        $output = ($lines | ForEach-Object { $_.ToString() }) -join "`n"
        $lines | ForEach-Object { Write-Host "  $_" }
    } catch {
        Write-Host "  Erro: $_" -ForegroundColor Red
        Write-Log -Message "Erro em Test-SfcHealth: $_" -Level "ERROR"
        $output = "Erro: $_"
    }

    Write-Log -Message "Test-SfcHealth concluido" -Level "INFO"
    return @{ Status = $output }
}

# ---------------------------------------------------------------------------
function Invoke-SfcScan {
    <#
    .SYNOPSIS
        Executa sfc /scannow para reparar arquivos corrompidos. Requer Administrador.
    #>

    Write-Host ""
    Write-Host "[ SFC - Reparar Sistema (sfc /scannow) ]" -ForegroundColor Yellow

    if (-not (Test-IsWindows)) {
        Write-Host "  Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Invoke-SfcScan chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    if (-not (Test-IsAdmin)) {
        Write-Host "  AVISO: Execute o Atlas como Administrador para usar esta funcao." -ForegroundColor Red
        Write-Log -Message "Invoke-SfcScan: privilegios de Administrador necessarios" -Level "WARN"
        return
    }

    Write-Host "  Executando: sfc /scannow ..." -ForegroundColor Cyan
    Write-Host "  Aguarde, isso pode demorar varios minutos." -ForegroundColor DarkGray
    Write-Log -Message "Invoke-SfcScan iniciado" -Level "INFO"

    try {
        & sfc /scannow
    } catch {
        Write-Host "  Erro: $_" -ForegroundColor Red
        Write-Log -Message "Erro em Invoke-SfcScan: $_" -Level "ERROR"
    }

    Write-Log -Message "Invoke-SfcScan concluido" -Level "INFO"
}

# ---------------------------------------------------------------------------
function Test-DismHealth {
    <#
    .SYNOPSIS
        Verifica saude da imagem Windows via DISM /CheckHealth (somente leitura).
    .OUTPUTS
        Hashtable com Status (string da saida do DISM)
    #>

    Write-Host ""
    Write-Host "[ DISM - CheckHealth ]" -ForegroundColor Yellow

    if (-not (Test-IsWindows)) {
        Write-Host "  Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Test-DismHealth chamado no Linux (sem acao)" -Level "INFO"
        return @{ Status = "N/A (Linux)" }
    }

    Write-Host "  Executando: DISM /CheckHealth ..." -ForegroundColor Cyan
    Write-Log -Message "Test-DismHealth iniciado" -Level "INFO"

    $output = "Erro ao executar"
    try {
        $lines  = & dism /Online /Cleanup-Image /CheckHealth 2>&1
        $output = ($lines | ForEach-Object { $_.ToString() }) -join "`n"
        $lines | ForEach-Object { Write-Host "  $_" }
    } catch {
        Write-Host "  Erro: $_" -ForegroundColor Red
        Write-Log -Message "Erro em Test-DismHealth: $_" -Level "ERROR"
        $output = "Erro: $_"
    }

    Write-Log -Message "Test-DismHealth concluido" -Level "INFO"
    return @{ Status = $output }
}

# ---------------------------------------------------------------------------
function Invoke-DismScan {
    <#
    .SYNOPSIS
        Executa DISM /ScanHealth para detectar corrupao na imagem. Requer Administrador.
    #>

    Write-Host ""
    Write-Host "[ DISM - ScanHealth ]" -ForegroundColor Yellow

    if (-not (Test-IsWindows)) {
        Write-Host "  Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Invoke-DismScan chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    if (-not (Test-IsAdmin)) {
        Write-Host "  AVISO: Execute o Atlas como Administrador para usar esta funcao." -ForegroundColor Red
        Write-Log -Message "Invoke-DismScan: privilegios de Administrador necessarios" -Level "WARN"
        return
    }

    Write-Host "  Executando: DISM /ScanHealth ..." -ForegroundColor Cyan
    Write-Host "  Aguarde, isso pode demorar varios minutos." -ForegroundColor DarkGray
    Write-Log -Message "Invoke-DismScan iniciado" -Level "INFO"

    try {
        & dism /Online /Cleanup-Image /ScanHealth 2>&1 | ForEach-Object { Write-Host "  $_" }
    } catch {
        Write-Host "  Erro: $_" -ForegroundColor Red
        Write-Log -Message "Erro em Invoke-DismScan: $_" -Level "ERROR"
    }

    Write-Log -Message "Invoke-DismScan concluido" -Level "INFO"
}

# ---------------------------------------------------------------------------
function Invoke-DismRestoreHealth {
    <#
    .SYNOPSIS
        Executa DISM /RestoreHealth para reparar imagem corrompida. Requer Administrador e internet.
    #>

    Write-Host ""
    Write-Host "[ DISM - RestoreHealth ]" -ForegroundColor Yellow

    if (-not (Test-IsWindows)) {
        Write-Host "  Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Invoke-DismRestoreHealth chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    if (-not (Test-IsAdmin)) {
        Write-Host "  AVISO: Execute o Atlas como Administrador para usar esta funcao." -ForegroundColor Red
        Write-Log -Message "Invoke-DismRestoreHealth: privilegios de Administrador necessarios" -Level "WARN"
        return
    }

    Write-Host "  Executando: DISM /RestoreHealth ..." -ForegroundColor Cyan
    Write-Host "  Aguarde, isso pode demorar varios minutos (requer internet)." -ForegroundColor DarkGray
    Write-Log -Message "Invoke-DismRestoreHealth iniciado" -Level "INFO"

    try {
        & dism /Online /Cleanup-Image /RestoreHealth 2>&1 | ForEach-Object { Write-Host "  $_" }
    } catch {
        Write-Host "  Erro: $_" -ForegroundColor Red
        Write-Log -Message "Erro em Invoke-DismRestoreHealth: $_" -Level "ERROR"
    }

    Write-Log -Message "Invoke-DismRestoreHealth concluido" -Level "INFO"
}

# ---------------------------------------------------------------------------
function Get-DefenderHealth {
    <#
    .SYNOPSIS
        Exibe status do Windows Defender: servico, protecao em tempo real e atualizacao.
    .OUTPUTS
        PSCustomObject com ServicoAtivo, ProtecaoTempoReal, UltimaAtualizacao, IdadeDefinicoes
    #>

    Write-Host ""
    Write-Host "[ Windows Defender ]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "  Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Get-DefenderHealth chamado no Linux (sem acao)" -Level "INFO"
        return $null
    }

    try {
        $mpStatus = Get-MpComputerStatus -ErrorAction Stop

        $svcAtivo  = $mpStatus.AMServiceEnabled
        $protReal  = $mpStatus.RealTimeProtectionEnabled
        $lastUpd   = $mpStatus.AntivirusSignatureLastUpdated

        $svcStr    = if ($svcAtivo) { "Ativo" } else { "INATIVO" }
        $protStr   = if ($protReal) { "Ativada" } else { "DESATIVADA" }
        $updStr    = if ($lastUpd) { $lastUpd.ToString("dd/MM/yyyy HH:mm") } else { "Desconhecido" }
        $ageVal    = if ($lastUpd) { ([datetime]::Now - $lastUpd).Days } else { -1 }
        $ageStr    = if ($ageVal -ge 0) { "$ageVal dia(s)" } else { "Desconhecido" }

        $svcColor  = if ($svcAtivo) { "Green" } else { "Red" }
        $protColor = if ($protReal) { "Green" } else { "Red" }
        $ageColor  = if ($ageVal -lt 0) { "DarkGray" } elseif ($ageVal -lt 2) { "Green" } elseif ($ageVal -lt 7) { "Yellow" } else { "Red" }

        Write-Host ("  {0,-40} : " -f "Servico")                  -NoNewline; Write-Host $svcStr  -ForegroundColor $svcColor
        Write-Host ("  {0,-40} : " -f "Protecao em tempo real")   -NoNewline; Write-Host $protStr -ForegroundColor $protColor
        Write-Host ("  {0,-40} : " -f "Ultima atualizacao")       -NoNewline; Write-Host $updStr  -ForegroundColor $ageColor
        Write-Host ("  {0,-40} : " -f "Idade das definicoes")     -NoNewline; Write-Host $ageStr  -ForegroundColor $ageColor
        Write-Host ""

        Write-Log -Message "Get-DefenderHealth executado" -Level "INFO"

        return [PSCustomObject]@{
            ServicoAtivo      = $svcAtivo
            ProtecaoTempoReal = $protReal
            UltimaAtualizacao = $updStr
            IdadeDefinicoes   = $ageVal
        }
    } catch {
        Write-Host "  Defender nao disponivel: $_" -ForegroundColor DarkGray
        Write-Log -Message "Erro em Get-DefenderHealth: $_" -Level "WARN"
        return $null
    }
}

# ---------------------------------------------------------------------------
function Get-WindowsUpdateHealth {
    <#
    .SYNOPSIS
        Lista os ultimos 20 updates instalados via Get-HotFix.
    .OUTPUTS
        Array de objetos HotFix
    #>

    Write-Host ""
    Write-Host "[ Windows Update - Ultimos 20 updates ]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "  Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Get-WindowsUpdateHealth chamado no Linux (sem acao)" -Level "INFO"
        return $null
    }

    try {
        $hotfixes = Get-HotFix -ErrorAction Stop |
            Sort-Object InstalledOn -Descending -ErrorAction SilentlyContinue |
            Select-Object -First 20

        $count = ($hotfixes | Measure-Object).Count

        if ($count -gt 0) {
            $hotfixes | Format-Table HotFixID, Description, InstalledOn, InstalledBy -AutoSize
        } else {
            Write-Host "  Nenhum update encontrado via Get-HotFix." -ForegroundColor DarkGray
        }

        Write-Log -Message "Get-WindowsUpdateHealth executado ($count updates)" -Level "INFO"
        return $hotfixes
    } catch {
        Write-Host "  Erro ao consultar updates: $_" -ForegroundColor DarkGray
        Write-Log -Message "Erro em Get-WindowsUpdateHealth: $_" -Level "WARN"
        return $null
    }
}

# ---------------------------------------------------------------------------
function Get-CriticalServicesHealth {
    <#
    .SYNOPSIS
        Verifica status dos servicos criticos: WinRM, BITS, Spooler, EventLog, DNS Client, Defender.
    .OUTPUTS
        Array de PSCustomObject com Servico e Status
    #>

    Write-Host ""
    Write-Host "[ Servicos Criticos ]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "  Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Get-CriticalServicesHealth chamado no Linux (sem acao)" -Level "INFO"
        return $null
    }

    $services = @(
        @{ Name = "WinRM";     Label = "WinRM (Gerenc. Remoto)" },
        @{ Name = "BITS";      Label = "BITS (Transfer. Background)" },
        @{ Name = "Spooler";   Label = "Spooler (Impressao)" },
        @{ Name = "EventLog";  Label = "EventLog (Log de Eventos)" },
        @{ Name = "Dnscache";  Label = "DNS Client (Cache DNS)" },
        @{ Name = "WinDefend"; Label = "Windows Defender" }
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($svc in $services) {
        $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if ($service) {
            $statusStr = $service.Status.ToString()
            $color = switch ($statusStr) {
                "Running" { "Green" }
                "Stopped" { "Red" }
                default   { "Yellow" }
            }
            Write-Host ("  {0,-38} : " -f $svc.Label) -NoNewline
            Write-Host $statusStr -ForegroundColor $color
            $results.Add([PSCustomObject]@{ Servico = $svc.Label; Status = $statusStr })
        } else {
            Write-Host ("  {0,-38} : " -f $svc.Label) -NoNewline
            Write-Host "Nao encontrado" -ForegroundColor DarkGray
            $results.Add([PSCustomObject]@{ Servico = $svc.Label; Status = "Nao encontrado" })
        }
    }

    Write-Host ""
    Write-Log -Message "Get-CriticalServicesHealth executado" -Level "INFO"
    return $results
}

# ---------------------------------------------------------------------------
function Get-PendingRebootStatus {
    <#
    .SYNOPSIS
        Verifica reboot pendente via tres chaves de registro: CBS, Windows Update e PendingFileRenameOperations.
    .OUTPUTS
        [bool] $true se reboot pendente
    #>

    Write-Host ""
    Write-Host "[ Reboot Pendente ]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "  Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Get-PendingRebootStatus chamado no Linux (sem acao)" -Level "INFO"
        return $false
    }

    $pending = $false
    $reasons = [System.Collections.Generic.List[string]]::new()

    # Component Based Servicing
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) {
        $pending = $true
        $reasons.Add("Component Based Servicing")
    }

    # Windows Update
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) {
        $pending = $true
        $reasons.Add("Windows Update")
    }

    # PendingFileRenameOperations
    $pfr = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
        -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if ($pfr -and $pfr.PendingFileRenameOperations) {
        $pending = $true
        $reasons.Add("PendingFileRenameOperations")
    }

    if ($pending) {
        Write-Host "  REBOOT PENDENTE detectado:" -ForegroundColor Red
        foreach ($r in $reasons) {
            Write-Host "    - $r" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Nenhum reboot pendente detectado." -ForegroundColor Green
    }

    Write-Host ""
    Write-Log -Message "Get-PendingRebootStatus executado (pending=$pending)" -Level "INFO"
    return $pending
}

# ---------------------------------------------------------------------------
function Invoke-WindowsHealthReport {
    <#
    .SYNOPSIS
        Orquestrador: executa todas as verificacoes de saude e exporta reports/windows-health.txt.
    #>

    Write-Log -Message "Invoke-WindowsHealthReport iniciado" -Level "INFO"

    $sfcResult    = Test-SfcHealth
    $dismResult   = Test-DismHealth
    $defResult    = Get-DefenderHealth
    $updResult    = Get-WindowsUpdateHealth
    $svcResult    = Get-CriticalServicesHealth
    $rebootResult = Get-PendingRebootStatus

    # Preparar diretorio de relatorios
    $reportsDir = Join-Path (Split-Path $PSScriptRoot -Parent) "reports"
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir | Out-Null
    }
    $reportPath = Join-Path $reportsDir "windows-health.txt"

    $timestamp = (Get-Date).ToString("dd/MM/yyyy HH:mm:ss")
    $hostnameRaw = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } elseif ($env:HOSTNAME) { $env:HOSTNAME } else { (& hostname 2>/dev/null) }
    $hostname    = if ($hostnameRaw) { $hostnameRaw } else { "desconhecido" }
    $platform    = if (Test-IsWindows) { "Windows" } else { "Linux" }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("ATLAS - Saude do Windows")
    $lines.Add(("Gerado em : {0}" -f $timestamp))
    $lines.Add(("Hostname  : {0}" -f $hostname))
    $lines.Add(("Plataforma: {0}" -f $platform))
    $lines.Add("=" * 50)
    $lines.Add("")

    if (-not (Test-IsWindows)) {
        $lines.Add("AVISO: Este relatorio e exclusivo do Windows.")
        $lines.Add("Execute no Windows para obter dados completos.")
    } else {
        # SFC
        $lines.Add("[ SFC ]")
        if ($sfcResult -and $sfcResult.Status) {
            foreach ($sfcLine in ($sfcResult.Status -split "`n")) {
                $lines.Add(("  {0}" -f $sfcLine.Trim()))
            }
        }
        $lines.Add("")

        # DISM
        $lines.Add("[ DISM ]")
        if ($dismResult -and $dismResult.Status) {
            foreach ($dismLine in ($dismResult.Status -split "`n")) {
                $lines.Add(("  {0}" -f $dismLine.Trim()))
            }
        }
        $lines.Add("")

        # Defender
        $lines.Add("[ DEFENDER ]")
        if ($defResult) {
            $svcStr2  = if ($defResult.ServicoAtivo) { "Ativo" } else { "INATIVO" }
            $protStr2 = if ($defResult.ProtecaoTempoReal) { "Ativada" } else { "DESATIVADA" }
            $ageVal   = $defResult.IdadeDefinicoes
            $ageStr2  = if ($ageVal -ge 0) { "$ageVal dia(s)" } else { "Desconhecido" }
            $lines.Add(("  {0,-38} : {1}" -f "Servico", $svcStr2))
            $lines.Add(("  {0,-38} : {1}" -f "Protecao em tempo real", $protStr2))
            $lines.Add(("  {0,-38} : {1}" -f "Ultima atualizacao", $defResult.UltimaAtualizacao))
            $lines.Add(("  {0,-38} : {1}" -f "Idade das definicoes", $ageStr2))
        } else {
            $lines.Add("  Defender nao disponivel.")
        }
        $lines.Add("")

        # Windows Update
        $lines.Add("[ WINDOWS UPDATE - ULTIMOS 20 ]")
        if ($updResult) {
            foreach ($u in $updResult) {
                $kb     = $u.HotFixID
                $desc   = $u.Description
                $instDt = if ($u.InstalledOn) { $u.InstalledOn.ToString("dd/MM/yyyy") } else { "N/A" }
                $lines.Add(("  {0,-12} {1,-30} {2}" -f $kb, $desc, $instDt))
            }
        } else {
            $lines.Add("  Nenhum update encontrado.")
        }
        $lines.Add("")

        # Servicos
        $lines.Add("[ SERVICOS CRITICOS ]")
        if ($svcResult) {
            foreach ($s in $svcResult) {
                $lines.Add(("  {0,-38} : {1}" -f $s.Servico, $s.Status))
            }
        } else {
            $lines.Add("  Dados nao disponiveis.")
        }
        $lines.Add("")

        # Reboot
        $lines.Add("[ REBOOT PENDENTE ]")
        $rebootStr = if ($rebootResult) { "SIM" } else { "Nao" }
        $lines.Add(("  Status: {0}" -f $rebootStr))
        $lines.Add("")
    }

    $lines | Set-Content -Path $reportPath -Encoding UTF8

    Write-Host ""
    Write-Host ("Relatorio exportado: {0}" -f $reportPath) -ForegroundColor Green
    Write-Log -Message "Invoke-WindowsHealthReport concluido. Relatorio: $reportPath" -Level "INFO"
}

# ---------------------------------------------------------------------------
function Show-WindowsHealthMenu {
    <#
    .SYNOPSIS
        Exibe o submenu interativo de Saude do Windows.
    #>

    $subRunning = $true
    while ($subRunning) {
        Clear-Host
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " Atlas - Saude do Windows"                 -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[1] Verificar SFC"
        Write-Host "[2] Executar SFC (requer Admin)"
        Write-Host "[3] Verificar DISM"
        Write-Host "[4] Scan DISM (requer Admin)"
        Write-Host "[5] RestoreHealth DISM (requer Admin)"
        Write-Host "[6] Status do Defender"
        Write-Host "[7] Historico de Updates"
        Write-Host "[8] Servicos Criticos"
        Write-Host "[9] Reboot Pendente"
        Write-Host "[0] Voltar"
        Write-Host ""

        $subOption = Read-Host "Escolha uma opcao"

        switch ($subOption) {
            "1" { Test-SfcHealth;             Wait-UserInput }
            "2" { Invoke-SfcScan;             Wait-UserInput }
            "3" { Test-DismHealth;            Wait-UserInput }
            "4" { Invoke-DismScan;            Wait-UserInput }
            "5" { Invoke-DismRestoreHealth;   Wait-UserInput }
            "6" { Get-DefenderHealth;         Wait-UserInput }
            "7" { Get-WindowsUpdateHealth;    Wait-UserInput }
            "8" { Get-CriticalServicesHealth; Wait-UserInput }
            "9" { Get-PendingRebootStatus;    Wait-UserInput }
            "0" { $subRunning = $false }
            default {
                Write-Host "Opcao invalida." -ForegroundColor Yellow
                Wait-UserInput
            }
        }
    }
}
