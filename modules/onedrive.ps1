# ==========================================
# Atlas — Modulo OneDrive
# ==========================================

# ──────────────────────────────────────────
# Helpers internos
# ──────────────────────────────────────────

function script:Test-IsWindowsOneDrive {
    return ($IsWindows -or $env:OS -eq 'Windows_NT')
}

function script:Confirm-OneDriveAction {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $resp = Read-Host "Confirmar? (s/N)"
    return ($resp -match '^[sS]$')
}

# ──────────────────────────────────────────
# [6] Localizar executavel (usada internamente por outras funcoes)
# ──────────────────────────────────────────

function Find-OneDriveExecutable {
    if (-not (script:Test-IsWindowsOneDrive)) { return $null }

    $candidates = @(
        "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
        "C:\Program Files\Microsoft OneDrive\OneDrive.exe",
        "C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe"
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

# ──────────────────────────────────────────
# [1] Verificar se OneDrive esta rodando
# ──────────────────────────────────────────

function Get-OneDriveStatus {
    Write-Log -Message "Verificando status do OneDrive" -Level "INFO"

    if (-not (script:Test-IsWindowsOneDrive)) {
        Write-Host ""
        Write-Host "OneDrive e disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""

    # Processo
    try {
        $procs = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Host ("  [RODANDO] OneDrive — PID(s): {0}" -f ($procs.Id -join ', ')) -ForegroundColor Green
        } else {
            Write-Host "  [PARADO] Processo OneDrive nao encontrado." -ForegroundColor Yellow
        }
    } catch {
        Write-Log -Message "Erro ao verificar processo OneDrive: $_" -Level "ERROR"
        Write-Host "  Erro ao verificar processo." -ForegroundColor Red
    }

    # Executavel
    $exePath = Find-OneDriveExecutable
    if ($exePath) {
        Write-Host "  [OK] Executavel: $exePath" -ForegroundColor Green
    } else {
        Write-Host "  [NAO ENCONTRADO] Executavel do OneDrive nao localizado nos caminhos padrao." -ForegroundColor Yellow
    }

    # Pasta do OneDrive
    if ($env:OneDrive -and (Test-Path $env:OneDrive)) {
        Write-Host "  [OK] Pasta OneDrive: $env:OneDrive" -ForegroundColor Green
    } elseif ($env:OneDriveConsumer -and (Test-Path $env:OneDriveConsumer)) {
        Write-Host "  [OK] Pasta OneDrive: $env:OneDriveConsumer" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Variavel de ambiente OneDrive nao configurada ou pasta nao encontrada." -ForegroundColor Gray
    }
}

# ──────────────────────────────────────────
# [2] Reiniciar OneDrive
# ──────────────────────────────────────────

function Restart-OneDriveSafe {
    Write-Log -Message "Iniciando reinicializacao do OneDrive" -Level "INFO"

    if (-not (script:Test-IsWindowsOneDrive)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    $exePath = Find-OneDriveExecutable
    if (-not $exePath) {
        Write-Log -Message "Executavel do OneDrive nao encontrado para reinicio" -Level "WARN"
        Write-Host ""
        Write-Host "Executavel do OneDrive nao encontrado. Verifique a instalacao." -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "Executavel: $exePath" -ForegroundColor Cyan

    if (-not (script:Confirm-OneDriveAction "Reiniciar o OneDrive?")) {
        Write-Log -Message "Reinicio do OneDrive cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "Encerrando OneDrive..." -ForegroundColor Gray
        Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        Write-Host "Iniciando OneDrive..." -ForegroundColor Gray
        Start-Process -FilePath $exePath
        Start-Sleep -Seconds 3

        $procs = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Log -Message "OneDrive reiniciado com sucesso (PID: $($procs[0].Id))" -Level "INFO"
            Write-Host "OneDrive reiniciado com sucesso." -ForegroundColor Green
        } else {
            Write-Log -Message "OneDrive pode nao ter iniciado apos reinicio" -Level "WARN"
            Write-Host "OneDrive iniciado, mas processo nao confirmado. Verifique manualmente." -ForegroundColor Yellow
        }
    } catch {
        Write-Log -Message "Erro ao reiniciar OneDrive: $_" -Level "ERROR"
        Write-Host "Erro ao reiniciar o OneDrive." -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [3] Resetar OneDrive
# ──────────────────────────────────────────

function Reset-OneDriveSafe {
    Write-Log -Message "Iniciando reset do OneDrive" -Level "INFO"

    if (-not (script:Test-IsWindowsOneDrive)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    $exePath = Find-OneDriveExecutable
    if (-not $exePath) {
        Write-Log -Message "Executavel do OneDrive nao encontrado para reset" -Level "WARN"
        Write-Host ""
        Write-Host "Executavel do OneDrive nao encontrado. Verifique a instalacao." -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "ATENCAO: O reset do OneDrive pode exigir nova sincronizacao completa." -ForegroundColor Yellow
    Write-Host "Os arquivos locais NAO serao apagados." -ForegroundColor Cyan
    Write-Host "Apos o reset, o OneDrive sera reiniciado automaticamente." -ForegroundColor Gray

    if (-not (script:Confirm-OneDriveAction "Resetar o OneDrive? (pode demorar e exigir nova sincronizacao)")) {
        Write-Log -Message "Reset do OneDrive cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "Executando reset: $exePath /reset ..." -ForegroundColor Gray
        Start-Process -FilePath $exePath -ArgumentList "/reset" -Wait -ErrorAction Stop
        Write-Log -Message "Reset do OneDrive executado" -Level "INFO"

        Write-Host "Aguardando 5 segundos antes de reiniciar..." -ForegroundColor Gray
        Start-Sleep -Seconds 5

        Write-Host "Reiniciando OneDrive..." -ForegroundColor Gray
        Start-Process -FilePath $exePath
        Start-Sleep -Seconds 3

        $procs = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Host "OneDrive resetado e reiniciado com sucesso." -ForegroundColor Green
        } else {
            Write-Host "Reset executado. Inicie o OneDrive manualmente se necessario." -ForegroundColor Yellow
        }
    } catch {
        Write-Log -Message "Erro ao resetar OneDrive: $_" -Level "ERROR"
        Write-Host "Erro ao resetar o OneDrive." -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [4] Abrir pasta do OneDrive
# ──────────────────────────────────────────

function Open-OneDriveFolder {
    Write-Log -Message "Abrindo pasta do OneDrive" -Level "INFO"

    if (-not (script:Test-IsWindowsOneDrive)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    $folderPath = $null
    if ($env:OneDrive -and (Test-Path $env:OneDrive)) {
        $folderPath = $env:OneDrive
    } elseif ($env:OneDriveConsumer -and (Test-Path $env:OneDriveConsumer)) {
        $folderPath = $env:OneDriveConsumer
    }

    if ($folderPath) {
        Write-Host ""
        Write-Host "Abrindo: $folderPath" -ForegroundColor Cyan
        try {
            Start-Process explorer.exe $folderPath
            Write-Log -Message "Pasta do OneDrive aberta: $folderPath" -Level "INFO"
        } catch {
            Write-Log -Message "Erro ao abrir pasta do OneDrive: $_" -Level "ERROR"
            Write-Host "Erro ao abrir a pasta." -ForegroundColor Red
        }
    } else {
        Write-Log -Message "Pasta do OneDrive nao encontrada" -Level "WARN"
        Write-Host ""
        Write-Host "Pasta do OneDrive nao encontrada." -ForegroundColor Yellow
        Write-Host "Verifique se o OneDrive esta configurado neste computador."
    }
}

# ──────────────────────────────────────────
# [5] Abrir logs do OneDrive
# ──────────────────────────────────────────

function Open-OneDriveLogs {
    Write-Log -Message "Abrindo pasta de logs do OneDrive" -Level "INFO"

    if (-not (script:Test-IsWindowsOneDrive)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    $logsPath = "$env:LOCALAPPDATA\Microsoft\OneDrive\logs"

    if (Test-Path $logsPath) {
        Write-Host ""
        Write-Host "Abrindo: $logsPath" -ForegroundColor Cyan
        try {
            Start-Process explorer.exe $logsPath
            Write-Log -Message "Pasta de logs do OneDrive aberta: $logsPath" -Level "INFO"
        } catch {
            Write-Log -Message "Erro ao abrir logs do OneDrive: $_" -Level "ERROR"
            Write-Host "Erro ao abrir a pasta de logs." -ForegroundColor Red
        }
    } else {
        Write-Log -Message "Pasta de logs do OneDrive nao encontrada: $logsPath" -Level "WARN"
        Write-Host ""
        Write-Host "Pasta de logs nao encontrada: $logsPath" -ForegroundColor Yellow
    }
}

# ──────────────────────────────────────────
# Menu OneDrive
# ──────────────────────────────────────────

function Show-OneDriveMenu {
    $odRunning = $true

    while ($odRunning) {
        Clear-Host
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  Atlas - OneDrive" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[1]  Verificar se OneDrive esta rodando"
        Write-Host "[2]  Reiniciar OneDrive"
        Write-Host "[3]  Resetar OneDrive"
        Write-Host "[4]  Abrir pasta do OneDrive"
        Write-Host "[5]  Abrir logs do OneDrive"
        Write-Host "[6]  Localizar executavel do OneDrive"
        Write-Host "[0]  Voltar"
        Write-Host ""

        $opt = Read-Host "Escolha uma opcao"

        switch ($opt) {
            "1" { Get-OneDriveStatus;      Wait-UserInput }
            "2" { Restart-OneDriveSafe;    Wait-UserInput }
            "3" { Reset-OneDriveSafe;      Wait-UserInput }
            "4" { Open-OneDriveFolder;     Wait-UserInput }
            "5" { Open-OneDriveLogs;       Wait-UserInput }
            "6" {
                $exe = Find-OneDriveExecutable
                Write-Host ""
                if ($exe) {
                    Write-Host "Executavel encontrado: $exe" -ForegroundColor Green
                    Write-Log -Message "Executavel OneDrive: $exe" -Level "INFO"
                } else {
                    Write-Host "Executavel do OneDrive nao encontrado nos caminhos padrao." -ForegroundColor Yellow
                    Write-Log -Message "Executavel do OneDrive nao encontrado" -Level "WARN"
                }
                Wait-UserInput
            }
            "0" {
                Write-Log -Message "Saindo do menu OneDrive" -Level "INFO"
                $odRunning = $false
            }
            default {
                Write-Log -Message "Opcao invalida no menu OneDrive: $opt" -Level "WARN"
                Write-Host "Opcao invalida." -ForegroundColor Yellow
                Wait-UserInput
            }
        }
    }
}
