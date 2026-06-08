# ==========================================
# Atlas - Modulo OneDrive
# ==========================================

# ------------------------------------------
# Helpers internos
# ------------------------------------------

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

# ------------------------------------------
# [6] Localizar executavel (usada internamente por outras funcoes)
# ------------------------------------------

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

# ------------------------------------------
# [1] Verificar se OneDrive esta rodando
# ------------------------------------------

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
            Write-Host ("  [RODANDO] OneDrive - PID(s): {0}" -f ($procs.Id -join ', ')) -ForegroundColor Green
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

    Write-AtlasLog -Nivel INFO -Modulo "OneDrive" -Acao "Consulta status" -Resultado "Sucesso"
}

# ------------------------------------------
# [2] Reiniciar OneDrive
# ------------------------------------------

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
            Write-AtlasLog -Nivel INFO -Modulo "OneDrive" -Acao "Reinicio" -Resultado "Sucesso"
        } else {
            Write-Log -Message "OneDrive pode nao ter iniciado apos reinicio" -Level "WARN"
            Write-Host "OneDrive iniciado, mas processo nao confirmado. Verifique manualmente." -ForegroundColor Yellow
            Write-AtlasLog -Nivel WARN -Modulo "OneDrive" -Acao "Reinicio" -Resultado "Falha"
        }
    } catch {
        Write-Log -Message "Erro ao reiniciar OneDrive: $_" -Level "ERROR"
        Write-Host "Erro ao reiniciar o OneDrive." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "OneDrive" -Acao "Reinicio" -Resultado "Falha"
    }
}

# ------------------------------------------
# [3] Resetar OneDrive
# ------------------------------------------

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
            Write-AtlasLog -Nivel INFO -Modulo "OneDrive" -Acao "Reset" -Resultado "Sucesso"
        } else {
            Write-Host "Reset executado. Inicie o OneDrive manualmente se necessario." -ForegroundColor Yellow
            Write-AtlasLog -Nivel WARN -Modulo "OneDrive" -Acao "Reset" -Resultado "Falha"
        }
    } catch {
        Write-Log -Message "Erro ao resetar OneDrive: $_" -Level "ERROR"
        Write-Host "Erro ao resetar o OneDrive." -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "OneDrive" -Acao "Reset" -Resultado "Falha"
    }
}

# ------------------------------------------
# [4] Abrir pasta do OneDrive
# ------------------------------------------

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

# ------------------------------------------
# [5] Abrir logs do OneDrive
# ------------------------------------------

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

# ------------------------------------------
# [7] Desinstalar OneDrive
# ------------------------------------------

function Find-OneDriveSetupExecutable {
    if (-not (script:Test-IsWindowsOneDrive)) { return $null }

    $candidates = @(
        (Join-Path $env:SystemRoot "SysWOW64\OneDriveSetup.exe"),
        (Join-Path $env:SystemRoot "System32\OneDriveSetup.exe"),
        "$env:LOCALAPPDATA\Microsoft\OneDrive\Update\OneDriveSetup.exe"
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

function Uninstall-OneDriveSafe {
    Write-Log -Message "Solicitacao de desinstalacao do OneDrive" -Level "INFO"

    if (-not (script:Test-IsWindowsOneDrive)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "ATENCAO: Esta acao remove o OneDrive deste computador." -ForegroundColor Red
    Write-Host "Seus arquivos na nuvem NAO serao apagados, mas a sincronizacao local sera removida." -ForegroundColor Yellow
    Write-Host ""
    $resp = Read-Host "Digite S para confirmar a desinstalacao"
    if ($resp -notmatch '^[sS]$') {
        Write-Log -Message "Desinstalacao do OneDrive cancelada" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "Encerrando processo OneDrive..." -ForegroundColor Gray
        Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } catch {
        Write-Log -Message "Aviso ao encerrar OneDrive: $_" -Level "WARN"
    }

    $setup = Find-OneDriveSetupExecutable
    if (-not $setup) {
        Write-Log -Message "OneDriveSetup.exe nao encontrado" -Level "WARN"
        Write-Host "OneDriveSetup.exe nao encontrado nos caminhos padrao." -ForegroundColor Red
        Write-Host "Use a opcao 9 para baixar e reinstalar manualmente." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Executando: $setup /uninstall" -ForegroundColor Cyan
        Start-Process -FilePath $setup -ArgumentList "/uninstall" -Wait -ErrorAction Stop
        Write-Log -Message "Desinstalacao do OneDrive executada via $setup" -Level "INFO"
        Write-Host "Comando de desinstalacao executado. Verifique se o OneDrive foi removido." -ForegroundColor Green
        Write-AtlasLog -Nivel INFO -Modulo "OneDrive" -Acao "Remocao" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao desinstalar OneDrive: $_" -Level "ERROR"
        Write-Host "Erro ao desinstalar OneDrive: $_" -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "OneDrive" -Acao "Remocao" -Resultado "Falha"
    }
}

# ------------------------------------------
# [8] Remover residuos do OneDrive
# ------------------------------------------

function Clear-OneDriveResidualFilesSafe {
    Write-Log -Message "Solicitacao de limpeza de residuos do OneDrive" -Level "INFO"

    if (-not (script:Test-IsWindowsOneDrive)) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    $residualPaths = @(
        "$env:LOCALAPPDATA\Microsoft\OneDrive",
        "$env:PROGRAMDATA\Microsoft OneDrive",
        "$env:LOCALAPPDATA\OneDrive"
    )

    $existing = @()
    foreach ($p in $residualPaths) {
        if (Test-Path $p) { $existing += $p }
    }

    if ($existing.Count -eq 0) {
        Write-Host ""
        Write-Host "Nenhuma pasta de residuo encontrada." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "ATENCAO: Remove caches e configuracoes locais do OneDrive." -ForegroundColor Red
    Write-Host "NAO apaga documentos do usuario nem pastas sincronizadas (ex.: env:OneDrive)." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pastas que serao removidas:" -ForegroundColor Yellow
    $existing | ForEach-Object { Write-Host "  - $_" }
    Write-Host ""
    $resp = Read-Host "Digite S para confirmar"
    if ($resp -notmatch '^[sS]$') {
        Write-Log -Message "Limpeza de residuos OneDrive cancelada" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    $cleanupOk = $true
    foreach ($p in $existing) {
        try {
            Write-Host "Removendo: $p ..." -ForegroundColor Gray
            Remove-Item -Path $p -Recurse -Force -ErrorAction Stop
            Write-Log -Message "Residuo removido: $p" -Level "INFO"
            Write-Host "  [OK] $p" -ForegroundColor Green
        } catch {
            Write-Log -Message "Erro ao remover $p : $_" -Level "ERROR"
            Write-Host "  [ERRO] $p : $_" -ForegroundColor Red
            $cleanupOk = $false
        }
    }

    if ($cleanupOk) {
        Write-AtlasLog -Nivel INFO -Modulo "OneDrive" -Acao "Limpeza residuos" -Resultado "Sucesso"
    } else {
        Write-AtlasLog -Nivel ERROR -Modulo "OneDrive" -Acao "Limpeza residuos" -Resultado "Falha"
    }
}

# ------------------------------------------
# [9] Pagina oficial de download
# ------------------------------------------

function Open-OneDriveDownloadPage {
    Write-Log -Message "Abrindo pagina oficial do OneDrive" -Level "INFO"
    $url = "https://www.microsoft.com/pt-br/microsoft-365/onedrive/download"
    try {
        Start-Process $url
        Write-Host ""
        Write-Host "Pagina oficial aberta no navegador." -ForegroundColor Green
        Write-Host "Baixe e instale o OneDrive manualmente." -ForegroundColor Gray
        Write-AtlasLog -Nivel INFO -Modulo "OneDrive" -Acao "Reinstalacao" -Resultado "Sucesso"
    } catch {
        Write-Log -Message "Erro ao abrir pagina OneDrive: $_" -Level "ERROR"
        Write-Host "Erro ao abrir navegador: $_" -ForegroundColor Red
        Write-AtlasLog -Nivel ERROR -Modulo "OneDrive" -Acao "Reinstalacao" -Resultado "Falha"
    }
}

# ------------------------------------------
# Menu OneDrive
# ------------------------------------------

function Show-OneDriveMenu {
    $odRunning = $true

    while ($odRunning) {
        Show-AtlasMenuHeader -Title "OneDrive"

        Show-AtlasMenuOption -Number "1" -Name "Verificar status do OneDrive" `
            -Description "Mostra se o OneDrive esta aberto e sincronizando" -Risk "nenhum"
        Show-AtlasMenuOption -Number "2" -Name "Reiniciar OneDrive" `
            -Description "Fecha e abre o OneDrive novamente" -Risk "baixo"
        Show-AtlasMenuOption -Number "3" -Name "Resetar OneDrive" `
            -Description "Restaura configuracoes padrao do OneDrive" -Risk "medio"
        Show-AtlasMenuOption -Number "4" -Name "Abrir pasta do OneDrive" `
            -Description "Abre a pasta sincronizada no Explorer" -Risk "nenhum"
        Show-AtlasMenuOption -Number "5" -Name "Abrir logs do OneDrive" `
            -Description "Acessa registros para diagnostico avancado" -Risk "nenhum"
        Show-AtlasMenuOption -Number "6" -Name "Localizar executavel do OneDrive" `
            -Description "Encontra onde o OneDrive esta instalado" -Risk "nenhum"
        Show-AtlasMenuOption -Number "7" -Name "Desinstalar OneDrive" `
            -Description "Remove o OneDrive deste computador" -Risk "alto"
        Show-AtlasMenuOption -Number "8" -Name "Remover residuos do OneDrive" `
            -Description "Apaga pastas e arquivos antigos do OneDrive" -Risk "medio"
        Show-AtlasMenuOption -Number "9" -Name "Pagina oficial para reinstalar" `
            -Description "Abre o site da Microsoft para baixar novamente" -Risk "nenhum"

        Show-AtlasMenuBackOption
        $opt = Read-AtlasMenuChoice

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
            "7" { Uninstall-OneDriveSafe;      Wait-UserInput }
            "8" { Clear-OneDriveResidualFilesSafe; Wait-UserInput }
            "9" { Open-OneDriveDownloadPage;   Wait-UserInput }
            "0" {
                Write-Log -Message "Saindo do menu OneDrive" -Level "INFO"
                $odRunning = $false
            }
            default {
                Write-Log -Message "Opcao invalida no menu OneDrive: $opt" -Level "WARN"
                Write-AtlasWarning "Opcao invalida."
                Wait-UserInput
            }
        }
    }
}
