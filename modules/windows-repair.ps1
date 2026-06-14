# ==========================================
# Atlas - Modulo de Reparos Windows
# ==========================================

# ------------------------------------------
# Helpers internos
# ------------------------------------------

function script:Test-IsWindowsRepair {
    return ($IsWindows -or $env:OS -eq 'Windows_NT')
}

function script:Confirm-RepairAction {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $resp = Read-Host "Confirmar? (s/N)"
    return ($resp -match '^[sS]$')
}

function script:Test-RepairAdmin {
    if (script:Test-IsWindowsRepair) {
        $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    return $false
}

# ------------------------------------------
# [1] Verificar integridade SFC (somente leitura)
# ------------------------------------------

function Test-SfcVerifyOnly {
    Write-Log -Message "Executando SFC /verifyonly" -Level "INFO"

    if (-not (script:Test-IsWindowsRepair)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Executando: sfc /verifyonly" -ForegroundColor Cyan
    Write-Host "Apenas verifica - nenhuma alteracao sera feita." -ForegroundColor Gray

    try {
        & sfc /verifyonly
        Write-Log -Message "SFC /verifyonly concluido" -Level "INFO"
        Write-AtlasLog -Nivel INFO -Modulo "Reparos Windows" -Acao "SFC Verify" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao executar SFC /verifyonly: $_" -Level "ERROR"
        Write-Host "Erro ao executar SFC." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Reparos Windows" -Acao "SFC Verify" -Resultado "Falha"
    }
}

# ------------------------------------------
# [2] SFC /scannow
# ------------------------------------------

function Invoke-SfcScannowSafe {
    Write-Log -Message "Iniciando SFC /scannow" -Level "INFO"

    if (-not (script:Test-IsWindowsRepair)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    if (-not (script:Test-RepairAdmin)) {
        Write-Log -Message "SFC /scannow requer privilegios de administrador" -Level "WARN"
        Write-Host ""
        Write-Host "Execute o Atlas como Administrador para usar o SFC /scannow." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "O SFC /scannow verifica e repara arquivos de sistema corrompidos." -ForegroundColor Cyan
    Write-Host "Pode levar varios minutos. Nao feche o terminal durante a execucao." -ForegroundColor Gray

    if (-not (script:Confirm-RepairAction "Executar SFC /scannow?")) {
        Write-Log -Message "SFC /scannow cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "Executando SFC /scannow..." -ForegroundColor Gray
        & sfc /scannow
        Write-Log -Message "SFC /scannow concluido" -Level "INFO"
        Write-Host ""
        Write-Host "SFC concluido. Verifique o resultado acima." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Reparos Windows" -Acao "SFC Scannow" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao executar SFC /scannow: $_" -Level "ERROR"
        Write-Host "Erro durante o SFC." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Reparos Windows" -Acao "SFC Scannow" -Resultado "Falha"
    }
}

# ------------------------------------------
# [3] DISM CheckHealth (somente leitura)
# ------------------------------------------

function Test-DismCheckHealth {
    Write-Log -Message "Executando DISM CheckHealth" -Level "INFO"

    if (-not (script:Test-IsWindowsRepair)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Executando: DISM /Online /Cleanup-Image /CheckHealth" -ForegroundColor Cyan
    Write-Host "Apenas verifica estado da imagem - nenhuma alteracao sera feita." -ForegroundColor Gray

    try {
        & DISM /Online /Cleanup-Image /CheckHealth
        Write-Log -Message "DISM CheckHealth concluido" -Level "INFO"
        Write-AtlasLog -Nivel INFO -Modulo "Reparos Windows" -Acao "DISM CheckHealth" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao executar DISM CheckHealth: $_" -Level "ERROR"
        Write-Host "Erro ao executar DISM CheckHealth." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Reparos Windows" -Acao "DISM CheckHealth" -Resultado "Falha"
    }
}

# ------------------------------------------
# [4] DISM ScanHealth
# ------------------------------------------

function Invoke-DismScanHealthSafe {
    Write-Log -Message "Iniciando DISM ScanHealth" -Level "INFO"

    if (-not (script:Test-IsWindowsRepair)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "O DISM ScanHealth faz uma varredura completa da imagem do Windows." -ForegroundColor Cyan
    Write-Host "Pode levar varios minutos. Nenhum reparo sera feito nesta etapa." -ForegroundColor Gray

    if (-not (script:Confirm-RepairAction "Executar DISM ScanHealth?")) {
        Write-Log -Message "DISM ScanHealth cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "Executando DISM ScanHealth..." -ForegroundColor Gray
        & DISM /Online /Cleanup-Image /ScanHealth
        Write-Log -Message "DISM ScanHealth concluido" -Level "INFO"
        Write-Host ""
        Write-Host "DISM ScanHealth concluido. Verifique o resultado acima." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Reparos Windows" -Acao "DISM ScanHealth" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao executar DISM ScanHealth: $_" -Level "ERROR"
        Write-Host "Erro durante o DISM ScanHealth." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Reparos Windows" -Acao "DISM ScanHealth" -Resultado "Falha"
    }
}

# ------------------------------------------
# [5] DISM RestoreHealth
# ------------------------------------------

function Invoke-DismRestoreHealthSafe {
    Write-Log -Message "Iniciando DISM RestoreHealth" -Level "INFO"

    if (-not (script:Test-IsWindowsRepair)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    if (-not (script:Test-RepairAdmin)) {
        Write-Log -Message "DISM RestoreHealth requer privilegios de administrador" -Level "WARN"
        Write-Host ""
        Write-Host "Execute o Atlas como Administrador para usar o DISM RestoreHealth." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "O DISM RestoreHealth baixa e repara arquivos corrompidos da imagem do Windows." -ForegroundColor Cyan
    Write-Host "Requer conexao com a internet. Pode levar 15-30 minutos." -ForegroundColor Gray
    Write-Host "Nao feche o terminal durante a execucao." -ForegroundColor Gray

    if (-not (script:Confirm-RepairAction "Executar DISM RestoreHealth?")) {
        Write-Log -Message "DISM RestoreHealth cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "Executando DISM RestoreHealth..." -ForegroundColor Gray
        & DISM /Online /Cleanup-Image /RestoreHealth
        Write-Log -Message "DISM RestoreHealth concluido" -Level "INFO"
        Write-Host ""
        Write-Host "DISM RestoreHealth concluido. Verifique o resultado acima." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Reparos Windows" -Acao "DISM RestoreHealth" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao executar DISM RestoreHealth: $_" -Level "ERROR"
        Write-Host "Erro durante o DISM RestoreHealth." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Reparos Windows" -Acao "DISM RestoreHealth" -Resultado "Falha"
    }
}

# ------------------------------------------
# [6] Reset Windows Update
# ------------------------------------------

function Reset-WindowsUpdateSafe {
    Write-Log -Message "Iniciando reset dos componentes do Windows Update" -Level "INFO"

    if (-not (script:Test-IsWindowsRepair)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    if (-not (script:Test-RepairAdmin)) {
        Write-Log -Message "Reset do Windows Update requer privilegios de administrador" -Level "WARN"
        Write-Host ""
        Write-Host "Execute o Atlas como Administrador para resetar o Windows Update." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Esta acao ira:" -ForegroundColor Cyan
    Write-Host "  1. Parar servicos: wuauserv, bits, cryptsvc, msiserver" -ForegroundColor Gray
    Write-Host "  2. Renomear SoftwareDistribution -> SoftwareDistribution.old_<timestamp>" -ForegroundColor Gray
    Write-Host "  3. Renomear catroot2 -> catroot2.old_<timestamp>" -ForegroundColor Gray
    Write-Host "  4. Reiniciar os servicos" -ForegroundColor Gray
    Write-Host ""
    Write-Host "O Windows Update precisara recriar sua base de dados na proxima execucao." -ForegroundColor Yellow

    if (-not (script:Confirm-RepairAction "Resetar componentes do Windows Update?")) {
        Write-Log -Message "Reset do Windows Update cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    $services   = @('wuauserv', 'bits', 'cryptsvc', 'msiserver')
    $timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
    $sdPath     = "$env:SystemRoot\SoftwareDistribution"
    $cr2Path    = "$env:SystemRoot\System32\catroot2"
    $sdOld      = "${sdPath}.old_${timestamp}"
    $cr2Old     = "${cr2Path}.old_${timestamp}"

    try {
        # Parar servicos
        Write-Host "Parando servicos..." -ForegroundColor Gray
        foreach ($svc in $services) {
            try {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Write-Log -Message "Servico parado: $svc" -Level "INFO"
            } catch {
                Write-Log -Message "Nao foi possivel parar $svc (pode ja estar parado)" -Level "WARN"
            }
        }

        # Renomear SoftwareDistribution
        if (Test-Path $sdPath) {
            Rename-Item -Path $sdPath -NewName $sdOld -ErrorAction Stop
            Write-Log -Message "Renomeado: $sdPath -> $sdOld" -Level "INFO"
            Write-Host "  Renomeado: SoftwareDistribution -> SoftwareDistribution.old_$timestamp" -ForegroundColor Green
        } else {
            Write-Log -Message "SoftwareDistribution nao encontrado em $sdPath" -Level "WARN"
            Write-Host "  SoftwareDistribution nao encontrado." -ForegroundColor Gray
        }

        # Renomear catroot2
        if (Test-Path $cr2Path) {
            Rename-Item -Path $cr2Path -NewName $cr2Old -ErrorAction Stop
            Write-Log -Message "Renomeado: $cr2Path -> $cr2Old" -Level "INFO"
            Write-Host "  Renomeado: catroot2 -> catroot2.old_$timestamp" -ForegroundColor Green
        } else {
            Write-Log -Message "catroot2 nao encontrado em $cr2Path" -Level "WARN"
            Write-Host "  catroot2 nao encontrado." -ForegroundColor Gray
        }

        # Reiniciar servicos
        Write-Host "Reiniciando servicos..." -ForegroundColor Gray
        foreach ($svc in $services) {
            try {
                Start-Service -Name $svc -ErrorAction SilentlyContinue
                Write-Log -Message "Servico reiniciado: $svc" -Level "INFO"
            } catch {
                Write-Log -Message "Nao foi possivel reiniciar $svc" -Level "WARN"
            }
        }

        Write-Log -Message "Reset do Windows Update concluido com sucesso" -Level "INFO"
        Write-Host ""
        Write-Host "Reset concluido. O Windows Update sera reinicializado na proxima verificacao." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Reparos Windows" -Acao "Reset Windows Update" -Resultado "Sucesso"

    } catch {
        # Garantir que os servicos sejam reiniciados mesmo em caso de erro
        Write-Log -Message "Erro durante reset do Windows Update: $_" -Level "ERROR"
        Write-Host "Erro durante o reset. Tentando reiniciar servicos..." -ForegroundColor Red
        foreach ($svc in $services) {
            try { Start-Service -Name $svc -ErrorAction SilentlyContinue } catch { }
        }
        Write-Host "Servicos reiniciados. Verifique o log para detalhes." -ForegroundColor Yellow
        Write-AtlasLog -Nivel ERROR -Modulo "Reparos Windows" -Acao "Reset Windows Update" -Resultado "Falha"
    }
}

# ------------------------------------------
# Diagnostico guiado
# ------------------------------------------

function script:Invoke-SfcVerifyOnlyCapture {
    try {
        $output = & sfc /verifyonly 2>&1 | Out-String
        $hasCorruption = $output -match '(?i)(found corrupt|corrupt files|arquivos corrompidos|integrity violations were found)'
        $isClean = $output -match '(?i)(did not find any integrity violations|nao encontrou violac|n.o encontrou viola)'

        if ($hasCorruption -and -not $isClean) {
            return @{ Status = "problem"; Output = $output }
        }
        if ($isClean) {
            return @{ Status = "ok"; Output = $output }
        }
        return @{ Status = "unknown"; Output = $output }
    } catch {
        return @{ Status = "error"; Output = $_.Exception.Message }
    }
}

function script:Invoke-DismCheckHealthCapture {
    try {
        $output = & DISM /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String
        $hasCorruption = $output -match '(?i)(corruption was detected|corrupcao.*detectada|component store is repairable|reparavel)'
        $isClean = $output -match '(?i)(no component store corruption|nenhuma corrupcao)'

        if ($hasCorruption) {
            return @{ Status = "problem"; Output = $output }
        }
        if ($isClean) {
            return @{ Status = "ok"; Output = $output }
        }
        return @{ Status = "unknown"; Output = $output }
    } catch {
        return @{ Status = "error"; Output = $_.Exception.Message }
    }
}

function script:Test-PendingRebootCapture {
    if (-not (script:Test-IsWindowsRepair)) {
        return @{ Pending = $false; Reasons = @() }
    }

    $pending = $false
    $reasons = [System.Collections.Generic.List[string]]::new()

    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) {
        $pending = $true
        $reasons.Add("Component Based Servicing")
    }

    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) {
        $pending = $true
        $reasons.Add("Windows Update")
    }

    $pfr = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
        -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if ($pfr -and $pfr.PendingFileRenameOperations) {
        $pending = $true
        $reasons.Add("PendingFileRenameOperations")
    }

    return @{ Pending = $pending; Reasons = @($reasons) }
}

function script:Test-WindowsUpdateIssueCapture {
    if (-not (script:Test-IsWindowsRepair)) {
        return @{ HasIssue = $false; Detail = "" }
    }

    try {
        $svc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
        if ($svc -and $svc.StartType -ne 'Disabled' -and $svc.Status -ne 'Running') {
            return @{ HasIssue = $true; Detail = "Servico Windows Update parado ($($svc.Status))" }
        }
    } catch { }

    $sdPath = "$env:SystemRoot\SoftwareDistribution\Download"
    if (Test-Path $sdPath) {
        try {
            $staleFiles = Get-ChildItem -Path $sdPath -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
            if ($staleFiles -and @($staleFiles).Count -gt 50) {
                return @{ HasIssue = $true; Detail = "Cache de atualizacoes antigo detectado" }
            }
        } catch { }
    }

    return @{ HasIssue = $false; Detail = "" }
}

function Start-WindowsDiagnostic {
    Write-Log -Message "Iniciando diagnostico guiado do Windows" -Level "INFO"

    if (-not (script:Test-IsWindowsRepair)) {
        Write-Host ""
        Write-AtlasWarning "Funcao disponivel apenas no Windows."
        return
    }

    Write-Host ""
    Write-AtlasInfo "Executando diagnostico do sistema. Aguarde..."
    Write-Host ""

    Write-AtlasInfo "Etapa 1/3: Verificando arquivos do Windows..."
    $sfcResult = script:Invoke-SfcVerifyOnlyCapture
    Write-Log -Message "Diagnostico SFC: $($sfcResult.Status)" -Level "INFO"

    Write-AtlasInfo "Etapa 2/3: Verificando imagem do Windows..."
    $dismResult = script:Invoke-DismCheckHealthCapture
    Write-Log -Message "Diagnostico DISM: $($dismResult.Status)" -Level "INFO"

    Write-AtlasInfo "Etapa 3/3: Verificando atualizacoes e reinicializacao..."
    $rebootResult = script:Test-PendingRebootCapture
    $wuResult = script:Test-WindowsUpdateIssueCapture
    Write-Log -Message "Diagnostico reboot pendente: $($rebootResult.Pending)" -Level "INFO"
    Write-Log -Message "Diagnostico Windows Update: $($wuResult.HasIssue)" -Level "INFO"

    $findings = [System.Collections.Generic.List[string]]::new()
    $recommendations = [System.Collections.Generic.List[string]]::new()
    $hasAttention = $false

    if ($sfcResult.Status -eq "problem") {
        $findings.Add("SFC: Arquivos corrompidos detectados")
        $hasAttention = $true
        $recommendations.Add("Executar opcao [3] Corrigir arquivos do Windows")
    } elseif ($sfcResult.Status -eq "ok") {
        $findings.Add("SFC: Nenhum problema encontrado nos arquivos do Windows")
    } else {
        $findings.Add("SFC: Nao foi possivel interpretar o resultado.")
        $hasAttention = $true
        $recommendations.Add("Recomendacao: execute [2] Verificar arquivos do Windows.")
    }

    if ($dismResult.Status -eq "problem") {
        $findings.Add("DISM: Problemas detectados na imagem do Windows")
        $hasAttention = $true
        if (-not ($recommendations -contains "Executar opcao [5] Reparar imagem do Windows")) {
            $recommendations.Add("Executar opcao [5] Reparar imagem do Windows")
        }
    } elseif ($dismResult.Status -eq "ok") {
        $findings.Add("DISM: Imagem do Windows em bom estado")
    } else {
        $findings.Add("DISM: Nao foi possivel interpretar o resultado.")
        $hasAttention = $true
        $recommendations.Add("Recomendacao: execute [4] Verificar imagem do Windows.")
    }

    if ($rebootResult.Pending) {
        $reasonText = ($rebootResult.Reasons -join ", ")
        $findings.Add("Reinicializacao pendente detectada ($reasonText)")
        $hasAttention = $true
        if ($recommendations.Count -eq 0) {
            $recommendations.Add("Reinicie o computador antes de continuar com reparos")
        }
    }

    if ($wuResult.HasIssue) {
        $findings.Add("Problemas com Windows Update: $($wuResult.Detail)")
        $hasAttention = $true
        if ($recommendations.Count -eq 0) {
            $recommendations.Add("Executar opcao [6] Resetar Windows Update")
        }
    } elseif ($rebootResult.Reasons -contains "Windows Update") {
        $findings.Add("Atualizacoes pendentes detectadas")
        $hasAttention = $true
        if ($recommendations.Count -eq 0) {
            $recommendations.Add("Executar opcao [6] Resetar Windows Update")
        }
    }

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " Diagnostico do Sistema" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    foreach ($finding in $findings) {
        $isOk = $finding -match '(?i)(nenhum problema|em bom estado)'
        if ($isOk) {
            Write-Host "[OK]" -ForegroundColor Green -NoNewline
            Write-Host " $finding" -ForegroundColor White
        } else {
            Write-Host "[ATENCAO]" -ForegroundColor Yellow -NoNewline
            Write-Host " $finding" -ForegroundColor White
        }
    }

    Write-Host ""
    if ($recommendations.Count -gt 0) {
        Write-Host "Recomendacao:" -ForegroundColor Cyan
        foreach ($rec in $recommendations) {
            Write-Host $rec -ForegroundColor White
        }
    } elseif (-not $hasAttention) {
        Write-AtlasSuccess "Seu sistema parece estar em ordem. Nenhuma acao necessaria no momento."
    } else {
        Write-AtlasInfo "Revise os itens acima e escolha a opcao adequada no menu de Reparos Windows."
    }

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan

    $logResult = if ($recommendations.Count -gt 0) { ($recommendations -join "; ") } else { "Concluido" }
    Write-AtlasLog -Nivel INFO -Modulo "Reparos Windows" -Acao "Diagnostico Guiado" -Resultado $logResult
}

# ------------------------------------------
# Menu de reparos Windows
# ------------------------------------------

function Show-WindowsRepairMenu {
    $repairRunning = $true

    while ($repairRunning) {
        Show-AtlasHeader -Title "Reparos Windows"

        Show-AtlasDescribedOption -Number "1" -Name "Diagnostico recomendado" `
            -Description "Analisa o Windows e sugere o proximo passo."
        Show-AtlasDescribedOption -Number "2" -Name "Verificar arquivos do Windows" `
            -Description "Apenas verifica problemas. Nao altera o sistema."
        Show-AtlasDescribedOption -Number "3" -Name "Corrigir arquivos do Windows" `
            -Description "Repara arquivos corrompidos com SFC."
        Show-AtlasDescribedOption -Number "4" -Name "Verificar imagem do Windows" `
            -Description "Analisa a integridade da instalacao."
        Show-AtlasDescribedOption -Number "5" -Name "Reparar imagem do Windows" `
            -Description "Corrige componentes danificados com DISM."
        Show-AtlasDescribedOption -Number "6" -Name "Resetar Windows Update" `
            -Description "Recria caches e servicos de atualizacao."

        Show-AtlasBackOption
        $opt = Read-AtlasMenuChoice

        switch ($opt) {
            "1" { Start-WindowsDiagnostic;              Wait-UserInput }
            "2" { Test-SfcVerifyOnly;                     Wait-UserInput }
            "3" { Invoke-SfcScannowSafe;                  Wait-UserInput }
            "4" { Test-DismCheckHealth;                   Wait-UserInput }
            "5" { Invoke-DismRestoreHealthSafe;           Wait-UserInput }
            "6" { Reset-WindowsUpdateSafe;                Wait-UserInput }
            "0" {
                Write-Log -Message "Saindo do menu de reparos Windows" -Level "INFO"
                $repairRunning = $false
            }
            default {
                Write-Log -Message "Opcao invalida no menu de reparos: $opt" -Level "WARN"
                Write-AtlasWarning "Opcao invalida."
                Wait-UserInput
            }
        }
    }
}

