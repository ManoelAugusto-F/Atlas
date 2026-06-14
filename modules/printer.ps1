# ==========================================
# Atlas - Modulo de Impressoras
# ==========================================

# ------------------------------------------
# Helpers internos
# ------------------------------------------

function script:Test-IsWindowsPrinter {
    return ($IsWindows -or $env:OS -eq 'Windows_NT')
}

function script:Confirm-PrinterAction {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $resp = Read-Host "Confirmar? (s/N)"
    return ($resp -match '^[sS]$')
}

function script:Test-PrinterAdmin {
    if (script:Test-IsWindowsPrinter) {
        $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    return $false
}

# ------------------------------------------
# [1] Listar impressoras
# ------------------------------------------

function Get-PrinterList {
    Write-Log -Message "Listando impressoras instaladas" -Level "INFO"

    if (-not (script:Test-IsWindowsPrinter)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    try {
        $printers = @(Get-Printer -ErrorAction Stop)
        $total = $printers.Count

        if ($total -eq 0) {
            Write-Host "Nenhuma impressora instalada encontrada." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Total: 0 impressora(s)" -ForegroundColor Gray
        } else {
            Write-Host "Impressoras instaladas:" -ForegroundColor Cyan
            $printers | ForEach-Object {
                $defaultMark = if ($_.Default) { " [PADRAO]" } else { "" }
                $shared      = if ($_.Shared)  { " [COMPARTILHADA]" } else { "" }
                Write-Host ("  {0}{1}{2} - {3}" -f $_.Name, $defaultMark, $shared, $_.PrinterStatus) -ForegroundColor White
            }
            Write-Host ""
            Write-Host "Total: $total impressora(s)" -ForegroundColor Gray
        }
        Write-AtlasLog -Nivel INFO -Modulo "Impressoras" -Acao "Diagnostico" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao listar impressoras: $_" -Level "ERROR"
        Write-Host "Erro ao listar impressoras. Modulo PrintManagement pode nao estar disponivel." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Impressoras" -Acao "Diagnostico" -Resultado "Falha"
    }
}

# ------------------------------------------
# [2] Ver fila de impressao
# ------------------------------------------

function Get-PrintQueueStatus {
    Write-Log -Message "Verificando fila de impressao" -Level "INFO"

    if (-not (script:Test-IsWindowsPrinter)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    try {
        $printers = Get-Printer -ErrorAction Stop
        if (-not $printers) {
            Write-Host "Nenhuma impressora encontrada." -ForegroundColor Yellow
            return
        }

        $totalJobs = 0
        foreach ($printer in $printers) {
            try {
                $jobs = Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue
                if ($jobs) {
                    Write-Host ("Impressora: {0}" -f $printer.Name) -ForegroundColor Cyan
                    $jobs | ForEach-Object {
                        Write-Host ("  [Job {0}] {1} - {2} - {3}" -f $_.Id, $_.DocumentName, $_.JobStatus, $_.SubmittedTime) -ForegroundColor White
                    }
                    $totalJobs += $jobs.Count
                }
            } catch {
                # Impressora sem suporte a Get-PrintJob - ignorar silenciosamente
            }
        }

        if ($totalJobs -eq 0) {
            Write-Host "Fila de impressao vazia em todas as impressoras." -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host ("Total de jobs na fila: {0}" -f $totalJobs) -ForegroundColor Yellow
        }
        Write-AtlasLog -Nivel INFO -Modulo "Impressoras" -Acao "Diagnostico fila" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao verificar fila de impressao: $_" -Level "ERROR"
        Write-Host "Erro ao verificar fila. Modulo PrintManagement pode nao estar disponivel." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Impressoras" -Acao "Diagnostico fila" -Resultado "Falha"
    }
}

# ------------------------------------------
# [3] Reiniciar Spooler
# ------------------------------------------

function Restart-SpoolerSafe {
    Write-Log -Message "Iniciando reinicio do Spooler" -Level "INFO"

    if (-not (script:Test-IsWindowsPrinter)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    if (-not (script:Test-PrinterAdmin)) {
        Write-Log -Message "Reinicio do Spooler requer privilegios de administrador" -Level "WARN"
        Write-Host ""
        Write-Host "Execute o Atlas como Administrador para reiniciar o Spooler." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Esta acao reinicia o servico Spooler (Print Spooler)." -ForegroundColor Cyan
    Write-Host "Impressoes em andamento podem ser interrompidas." -ForegroundColor Gray

    if (-not (script:Confirm-PrinterAction "Reiniciar o Spooler?")) {
        Write-Log -Message "Reinicio do Spooler cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "Reiniciando Spooler..." -ForegroundColor Gray
        Restart-Service -Name Spooler -Force -ErrorAction Stop
        Write-Log -Message "Spooler reiniciado com sucesso" -Level "INFO"
        Write-Host "Spooler reiniciado com sucesso." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Impressoras" -Acao "Reinicio spooler" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao reiniciar Spooler: $_" -Level "ERROR"
        Write-Host "Erro ao reiniciar o Spooler." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Impressoras" -Acao "Reinicio spooler" -Resultado "Falha"
    }
}

# ------------------------------------------
# [4] Limpar fila de impressao
# ------------------------------------------

function Clear-PrintQueueSafe {
    Write-Log -Message "Iniciando limpeza da fila de impressao" -Level "INFO"

    if (-not (script:Test-IsWindowsPrinter)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    if (-not (script:Test-PrinterAdmin)) {
        Write-Log -Message "Limpeza da fila requer privilegios de administrador" -Level "WARN"
        Write-Host ""
        Write-Host "Execute o Atlas como Administrador para limpar a fila de impressao." -ForegroundColor Yellow
        return
    }

    $spoolPath = "$env:SystemRoot\System32\spool\PRINTERS"
    Write-Host ""
    Write-Host "Esta acao ira:" -ForegroundColor Cyan
    Write-Host "  1. Parar o servico Spooler" -ForegroundColor Gray
    Write-Host "  2. Apagar todos os jobs em: $spoolPath" -ForegroundColor Gray
    Write-Host "  3. Reiniciar o servico Spooler" -ForegroundColor Gray
    Write-Host "Impressoes pendentes serao perdidas." -ForegroundColor Yellow

    if (-not (script:Confirm-PrinterAction "Limpar fila de impressao?")) {
        Write-Log -Message "Limpeza da fila cancelada pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "Parando Spooler..." -ForegroundColor Gray
        Stop-Service -Name Spooler -Force -ErrorAction Stop

        $removed = 0; $skipped = 0
        if (Test-Path $spoolPath) {
            $items = Get-ChildItem -Path $spoolPath -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                try {
                    Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                    $removed++
                } catch {
                    $skipped++
                }
            }
        }

        Write-Host "Iniciando Spooler..." -ForegroundColor Gray
        Start-Service -Name Spooler -ErrorAction Stop

        Write-Log -Message "Fila limpa: $removed jobs removidos, $skipped ignorados" -Level "INFO"
        Write-Host ("Concluido: {0} job(s) removido(s), {1} ignorado(s)." -f $removed, $skipped) -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "Impressoras" -Acao "Limpeza fila" -Resultado "Sucesso"
    } catch {
        # Garantir que o Spooler seja reiniciado mesmo em caso de erro
        try { Start-Service -Name Spooler -ErrorAction SilentlyContinue } catch { }
        Write-Log -Message "Erro ao limpar fila de impressao: $_" -Level "ERROR"
        Write-Host "Erro durante a limpeza. Spooler reiniciado." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "Impressoras" -Acao "Limpeza fila" -Resultado "Falha"
    }
}

# ------------------------------------------
# [5] Ver drivers de impressora
# ------------------------------------------

function Get-PrinterDrivers {
    Write-Log -Message "Listando drivers de impressora" -Level "INFO"

    if (-not (script:Test-IsWindowsPrinter)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    try {
        $drivers = Get-PrinterDriver -ErrorAction Stop
        if ($drivers) {
            Write-Host "Drivers de impressora instalados:" -ForegroundColor Cyan
            $drivers | ForEach-Object {
                Write-Host ("  {0} - {1}" -f $_.Name, $_.PrinterEnvironment) -ForegroundColor White
            }
            Write-Host ""
            Write-Host ("Total: {0} driver(s)" -f $drivers.Count) -ForegroundColor Gray
        } else {
            Write-Host "Nenhum driver de impressora encontrado." -ForegroundColor Yellow
        }
    } catch {
        Write-Log -Message "Erro ao listar drivers: $_" -Level "ERROR"
        Write-Host "Erro ao listar drivers. Modulo PrintManagement pode nao estar disponivel." -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [6] Instalar impressora TCP/IP
# ──────────────────────────────────────────

function Add-TcpIpPrinterSafe {
    Write-Log -Message "Iniciando adicao de impressora TCP/IP" -Level "INFO"

    $isWindows = $IsWindows -or ($env:OS -like "*Windows*")
    if (-not $isWindows) {
        Write-Host "Esta opcao so esta disponivel no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Instalar Impressora TCP/IP" -ForegroundColor Cyan
    Write-Host ""
    
    $printerIp = Read-Host "IP da impressora"
    if (-not $printerIp) {
        Write-Host "IP invalido." -ForegroundColor Yellow
        return
    }

    $printerName = Read-Host "Nome da impressora (ex: HP-LaserJet-3)"
    if (-not $printerName) {
        Write-Host "Nome invalido." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Confirmando criacao de porta TCP/IP para $printerIp..." -ForegroundColor Yellow
    $confirm = Read-Host "Continuar? (s/N)"
    if ($confirm -notmatch '^[sS]$') {
        Write-Host "Cancelado." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Criando porta TCP/IP..." -ForegroundColor Cyan
        
        # Criar porta (requer admin)
        $portName = "IP_$($printerIp -replace '\.', '_')"
        $port = @{
            Name = $portName
            PrinterHostAddress = $printerIp
            Protocol = "LPR"
            PortNumber = 9100
        }
        
        Add-PrinterPort @port -ErrorAction Stop
        Write-Host "Porta criada: $portName" -ForegroundColor Green
        
        # Adicionar impressora
        Write-Host "Adicionando impressora $printerName..." -ForegroundColor Cyan
        Add-Printer -Name $printerName -PortName $portName -DriverName "Generic / Text Only" -ErrorAction Stop
        
        Write-Host ""
        Write-Host "Impressora adicionada com sucesso!" -ForegroundColor Green
        Write-Host "Nome: $printerName" -ForegroundColor Gray
        Write-Host "IP: $printerIp" -ForegroundColor Gray
        Write-Log -Message "Impressora TCP/IP adicionada: $printerName ($printerIp)" -Level "INFO"
        
    } catch {
        Write-Log -Message "Erro ao adicionar impressora TCP/IP: $_" -Level "ERROR"
        Write-Host "Erro ao adicionar impressora: $_" -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [7] Adicionar impressora compartilhada (UNC)
# ──────────────────────────────────────────

function Add-SharedPrinterSafe {
    Write-Log -Message "Iniciando adicao de impressora compartilhada" -Level "INFO"

    $isWindows = $IsWindows -or ($env:OS -like "*Windows*")
    if (-not $isWindows) {
        Write-Host "Esta opcao so esta disponivel no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Adicionar Impressora Compartilhada" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Caminho UNC (exemplo: \\servidor\impressora)" -ForegroundColor Gray
    $uncPath = Read-Host "Caminho"
    if (-not $uncPath) {
        Write-Host "Caminho invalido." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Confirmando adicao de impressora compartilhada..." -ForegroundColor Yellow
    Write-Host "Caminho: $uncPath" -ForegroundColor Gray
    $confirm = Read-Host "Continuar? (s/N)"
    if ($confirm -notmatch '^[sS]$') {
        Write-Host "Cancelado." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Adicionando impressora compartilhada..." -ForegroundColor Cyan
        Add-Printer -ConnectionName $uncPath -ErrorAction Stop
        
        Write-Host ""
        Write-Host "Impressora compartilhada adicionada com sucesso!" -ForegroundColor Green
        Write-Host "Caminho: $uncPath" -ForegroundColor Gray
        Write-Log -Message "Impressora compartilhada adicionada: $uncPath" -Level "INFO"
        
    } catch {
        Write-Log -Message "Erro ao adicionar impressora compartilhada: $_" -Level "ERROR"
        Write-Host "Erro ao adicionar impressora: $_" -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# Menu de impressoras
# ──────────────────────────────────────────

function Show-PrinterMenu {
    $printerRunning = $true

    while ($printerRunning) {
        Show-AtlasHeader -Title "Impressoras"

        Show-AtlasCompactOption -Number "1" -Name "Listar impressoras"
        Show-AtlasCompactOption -Number "2" -Name "Ver fila de impressao"
        Show-AtlasCompactOption -Number "3" -Name "Reiniciar Spooler"
        Show-AtlasCompactOption -Number "4" -Name "Limpar fila"
        Show-AtlasCompactOption -Number "5" -Name "Ver drivers"
        Show-AtlasCompactOption -Number "6" -Name "Impressora TCP/IP"
        Show-AtlasCompactOption -Number "7" -Name "Impressora compartilhada"

        Show-AtlasBackOption
        $opt = Read-AtlasMenuChoice

        switch ($opt) {
            "1" { Get-PrinterList;                Wait-UserInput }
            "2" { Get-PrintQueueStatus;            Wait-UserInput }
            "3" { Restart-SpoolerSafe;             Wait-UserInput }
            "4" { Clear-PrintQueueSafe;            Wait-UserInput }
            "5" { Get-PrinterDrivers;              Wait-UserInput }
            "6" { Add-TcpIpPrinterSafe;             Wait-UserInput }
            "7" { Add-SharedPrinterSafe;           Wait-UserInput }
            "0" {
                Write-Log -Message "Saindo do menu de impressoras" -Level "INFO"
                $printerRunning = $false
            }
            default {
                Write-Log -Message "Opcao invalida no menu de impressoras: $opt" -Level "WARN"
                Write-AtlasWarning "Opcao invalida."
                Wait-UserInput
            }
        }
    }
}
