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
    } catch {
        Write-Log -Message "Erro ao executar SFC /verifyonly: $_" -Level "ERROR"
        Write-Host "Erro ao executar SFC." -ForegroundColor Red
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
    } catch {
        Write-Log -Message "Erro ao executar SFC /scannow: $_" -Level "ERROR"
        Write-Host "Erro durante o SFC." -ForegroundColor Red
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
    } catch {
        Write-Log -Message "Erro ao executar DISM CheckHealth: $_" -Level "ERROR"
        Write-Host "Erro ao executar DISM CheckHealth." -ForegroundColor Red
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
    } catch {
        Write-Log -Message "Erro ao executar DISM ScanHealth: $_" -Level "ERROR"
        Write-Host "Erro durante o DISM ScanHealth." -ForegroundColor Red
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
    } catch {
        Write-Log -Message "Erro ao executar DISM RestoreHealth: $_" -Level "ERROR"
        Write-Host "Erro durante o DISM RestoreHealth." -ForegroundColor Red
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

    } catch {
        # Garantir que os servicos sejam reiniciados mesmo em caso de erro
        Write-Log -Message "Erro durante reset do Windows Update: $_" -Level "ERROR"
        Write-Host "Erro durante o reset. Tentando reiniciar servicos..." -ForegroundColor Red
        foreach ($svc in $services) {
            try { Start-Service -Name $svc -ErrorAction SilentlyContinue } catch { }
        }
        Write-Host "Servicos reiniciados. Verifique o log para detalhes." -ForegroundColor Yellow
    }
}

# ------------------------------------------
# Menu de reparos Windows
# ------------------------------------------

function Show-WindowsRepairMenu {
    $repairRunning = $true

    while ($repairRunning) {
        Clear-Host
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  Atlas - Reparos Windows" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[1]  Verificar integridade SFC (somente leitura)"
        Write-Host "     Scan sem alteracoes - recomendado antes de reparar"
        Write-Host ""
        Write-Host "[2]  Executar SFC /scannow"
        Write-Host "     Verifica e repara arquivos corrompidos do Windows"
        Write-Host ""
        Write-Host "[3]  DISM CheckHealth (somente leitura)"
        Write-Host "     Verificar saude da imagem do Windows"
        Write-Host ""
        Write-Host "[4]  DISM ScanHealth"
        Write-Host "     Scan mais profundo de integridade da imagem"
        Write-Host ""
        Write-Host "[5]  DISM RestoreHealth"
        Write-Host "     Restaura componentes corrompidos da imagem"
        Write-Host ""
        Write-Host "[6]  Reset Windows Update"
        Write-Host "     Limpa cache e reseta servico Windows Update"
        Write-Host ""
        Write-Host "[0]  Voltar"
        Write-Host ""

        $opt = Read-Host "Escolha uma opcao"

        switch ($opt) {
            "1" { Test-SfcVerifyOnly;             Wait-UserInput }
            "2" { Invoke-SfcScannowSafe;           Wait-UserInput }
            "3" { Test-DismCheckHealth;            Wait-UserInput }
            "4" { Invoke-DismScanHealthSafe;       Wait-UserInput }
            "5" { Invoke-DismRestoreHealthSafe;    Wait-UserInput }
            "6" { Reset-WindowsUpdateSafe;         Wait-UserInput }
            "0" {
                Write-Log -Message "Saindo do menu de reparos Windows" -Level "INFO"
                $repairRunning = $false
            }
            default {
                Write-Log -Message "Opcao invalida no menu de reparos: $opt" -Level "WARN"
                Write-Host "Opcao invalida." -ForegroundColor Yellow
                Wait-UserInput
            }
        }
    }
}
