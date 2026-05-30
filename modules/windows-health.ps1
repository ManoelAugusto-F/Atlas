function Test-EssentialWindowsServices {

    Write-Host ""
    Write-Host "[ Servicos Essenciais do Windows ]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Test-EssentialWindowsServices chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    $essential = @("wuauserv", "BITS", "Spooler", "WinRM", "EventLog", "W32Time", "WinDefend")

    $results = foreach ($name in $essential) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc) {
            [PSCustomObject]@{
                Nome        = $svc.Name
                Descricao   = $svc.DisplayName.Substring(0, [Math]::Min(35, $svc.DisplayName.Length))
                Status      = $svc.Status
                Inicializacao = $svc.StartType
            }
        } else {
            [PSCustomObject]@{
                Nome        = $name
                Descricao   = "Nao encontrado"
                Status      = "N/A"
                Inicializacao = "N/A"
            }
        }
    }

    $results | Format-Table Nome, Descricao, Status, Inicializacao -AutoSize

    $stopped = $results | Where-Object { $_.Status -eq "Stopped" }
    if ($stopped) {
        Write-Host ("Servicos parados: {0}" -f ($stopped.Nome -join ", ")) -ForegroundColor Yellow
    } else {
        Write-Host "Todos os servicos essenciais estao em execucao." -ForegroundColor Green
    }

    Write-Log -Message "Test-EssentialWindowsServices executado" -Level "INFO"
}

function Get-HeavyUserFolders {

    Write-Host ""
    Write-Host "[ Tamanho de Pastas do Usuario ]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Get-HeavyUserFolders chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    $folders = @(
        @{ Label = "Downloads";       Path = [Environment]::GetFolderPath("UserProfile") + "\Downloads" },
        @{ Label = "Desktop";         Path = [Environment]::GetFolderPath("Desktop") },
        @{ Label = "Documents";       Path = [Environment]::GetFolderPath("MyDocuments") },
        @{ Label = "TEMP usuario";    Path = $env:TEMP },
        @{ Label = "Windows TEMP";    Path = "C:\Windows\Temp" }
    )

    foreach ($f in $folders) {
        Write-Host ("  {0,-18} : " -f $f.Label) -NoNewline
        if (Test-Path $f.Path) {
            try {
                $size = (Get-ChildItem -Path $f.Path -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                $sizeMB = [math]::Round($size / 1MB, 1)
                $color  = if ($sizeMB -gt 2048) { "Red" } elseif ($sizeMB -gt 512) { "Yellow" } else { "Green" }
                Write-Host ("{0} MB" -f $sizeMB) -ForegroundColor $color
            } catch {
                Write-Host "Erro ao calcular" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "Nao encontrada" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Log -Message "Get-HeavyUserFolders executado" -Level "INFO"
}

function Test-PendingReboot {

    Write-Host ""
    Write-Host "[ Reboot Pendente ]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Test-PendingReboot chamado no Linux (sem acao)" -Level "INFO"
        return $false
    }

    $pending = $false
    $reasons = [System.Collections.Generic.List[string]]::new()

    $checks = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending";
           Label = "Component Based Servicing" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired";
           Label = "Windows Update" }
    )

    foreach ($c in $checks) {
        if (Test-Path $c.Path -ErrorAction SilentlyContinue) {
            $pending = $true
            $reasons.Add($c.Label)
        }
    }

    $pfr = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
        -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if ($pfr -and $pfr.PendingFileRenameOperations) {
        $pending = $true
        $reasons.Add("PendingFileRenameOperations")
    }

    if ($pending) {
        Write-Host "  REBOOT PENDENTE!" -ForegroundColor Red
        foreach ($r in $reasons) { Write-Host ("  - {0}" -f $r) -ForegroundColor Yellow }
    } else {
        Write-Host "  Nenhum reboot pendente detectado." -ForegroundColor Green
    }

    Write-Host ""
    Write-Log -Message "Test-PendingReboot: pendente=$pending" -Level "INFO"
    return $pending
}

function Get-WindowsUpdateSummary {

    Write-Host ""
    Write-Host "[ Ultimas Atualizacoes Instaladas ]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Get-WindowsUpdateSummary chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    try {
        $hotfixes = Get-HotFix -ErrorAction Stop |
            Sort-Object InstalledOn -Descending |
            Select-Object -First 10

        if ($hotfixes) {
            $hotfixes | ForEach-Object {
                [PSCustomObject]@{
                    ID           = $_.HotFixID
                    Tipo         = $_.Description
                    InstaladoEm  = if ($_.InstalledOn) { $_.InstalledOn.ToString('dd/MM/yyyy') } else { 'N/A' }
                }
            } | Format-Table ID, Tipo, InstaladoEm -AutoSize
        } else {
            Write-Host "Nenhuma atualizacao encontrada." -ForegroundColor DarkGray
        }

        Write-Log -Message "Get-WindowsUpdateSummary executado" -Level "INFO"
    } catch {
        Write-Host "Erro ao obter atualizacoes: $_" -ForegroundColor Red
        Write-Log -Message "Erro em Get-WindowsUpdateSummary: $_" -Level "ERROR"
    }
}

function Get-BasicSecurityStatus {

    Write-Host ""
    Write-Host "[ Status de Seguranca Basica ]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Get-BasicSecurityStatus chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    # Defender
    Write-Host "  Microsoft Defender:" -ForegroundColor Cyan
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $avStatus = if ($mp.AntivirusEnabled) { "Ativado" } else { "DESATIVADO" }
        $rtStatus = if ($mp.RealTimeProtectionEnabled) { "Ativado" } else { "DESATIVADO" }
        $sigAge   = $mp.AntivirusSignatureAge
        Write-Host ("    Antivirus             : {0}" -f $avStatus) -ForegroundColor $(if ($mp.AntivirusEnabled) { "Green" } else { "Red" })
        Write-Host ("    Protecao em tempo real: {0}" -f $rtStatus) -ForegroundColor $(if ($mp.RealTimeProtectionEnabled) { "Green" } else { "Red" })
        Write-Host ("    Assinatura (dias)     : {0}" -f $sigAge)   -ForegroundColor $(if ($sigAge -le 3) { "Green" } else { "Yellow" })
    } catch {
        Write-Host "    Modulo Defender indisponivel." -ForegroundColor DarkGray
    }

    # Firewall
    Write-Host ""
    Write-Host "  Firewall (perfis):" -ForegroundColor Cyan
    try {
        $profiles = Get-NetFirewallProfile -ErrorAction Stop
        foreach ($p in $profiles) {
            $state = if ($p.Enabled) { "Ativado" } else { "DESATIVADO" }
            Write-Host ("    {0,-10}: {1}" -f $p.Name, $state) -ForegroundColor $(if ($p.Enabled) { "Green" } else { "Red" })
        }
    } catch {
        Write-Host "    Informacao de firewall indisponivel." -ForegroundColor DarkGray
    }

    # BitLocker
    Write-Host ""
    Write-Host "  BitLocker:" -ForegroundColor Cyan
    try {
        $bl = Get-BitLockerVolume -ErrorAction Stop
        foreach ($v in $bl) {
            Write-Host ("    {0}: {1} - {2}" -f $v.MountPoint, $v.ProtectionStatus, $v.VolumeStatus)
        }
    } catch {
        Write-Host "    Informacao de BitLocker indisponivel." -ForegroundColor DarkGray
    }

    # UAC
    Write-Host ""
    Write-Host "  UAC:" -ForegroundColor Cyan
    try {
        $uac = Get-ItemPropertyValue `
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
            -Name EnableLUA -ErrorAction Stop
        $uacStatus = if ($uac -eq 1) { "Ativado" } else { "DESATIVADO" }
        Write-Host ("    EnableLUA: {0}" -f $uacStatus) -ForegroundColor $(if ($uac -eq 1) { "Green" } else { "Red" })
    } catch {
        Write-Host "    Informacao de UAC indisponivel." -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Log -Message "Get-BasicSecurityStatus executado" -Level "INFO"
}
