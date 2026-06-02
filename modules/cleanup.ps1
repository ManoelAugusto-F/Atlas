# ==========================================
# Atlas — Modulo de Limpeza Segura
# ==========================================

# ──────────────────────────────────────────
# Helpers internos
# ──────────────────────────────────────────

function script:Test-IsAdmin {
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    return $false
}

function script:Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function script:Confirm-Action {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $resp = Read-Host "Confirmar? (s/N)"
    return ($resp -match '^[sS]$')
}

# ──────────────────────────────────────────
# [1] Maiores pastas do perfil
# ──────────────────────────────────────────

function Get-LargestUserFolders {
    Write-Log -Message "Listando maiores pastas do perfil" -Level "INFO"

    $profilePath = if ($IsWindows -or $env:OS -eq 'Windows_NT') { $env:USERPROFILE } else { $HOME }

    Write-Host ""
    Write-Host "Analisando: $profilePath" -ForegroundColor Cyan
    Write-Host "Aguarde..." -ForegroundColor Gray

    try {
        $folders = Get-ChildItem -Path $profilePath -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $size = 0
                try {
                    $size = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if (-not $size) { $size = 0 }
                } catch { }
                [PSCustomObject]@{ Nome = $_.Name; Tamanho = $size; Caminho = $_.FullName }
            } |
            Sort-Object -Property Tamanho -Descending |
            Select-Object -First 10

        if ($folders) {
            Write-Host ""
            Write-Host "Top 10 maiores pastas:" -ForegroundColor Cyan
            $folders | ForEach-Object {
                Write-Host ("  {0,-40} {1}" -f $_.Nome, (script:Format-FileSize $_.Tamanho))
            }
        } else {
            Write-Host "Nenhuma pasta encontrada." -ForegroundColor Yellow
        }
    } catch {
        Write-Log -Message "Erro ao listar pastas: $_" -Level "ERROR"
        Write-Host "Erro ao analisar pastas do perfil." -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [2] Maiores arquivos do perfil
# ──────────────────────────────────────────

function Get-LargestUserFiles {
    Write-Log -Message "Listando maiores arquivos do perfil" -Level "INFO"

    $profilePath = if ($IsWindows -or $env:OS -eq 'Windows_NT') { $env:USERPROFILE } else { $HOME }

    Write-Host ""
    Write-Host "Analisando: $profilePath" -ForegroundColor Cyan
    Write-Host "Aguarde..." -ForegroundColor Gray

    try {
        $files = Get-ChildItem -Path $profilePath -Recurse -File -ErrorAction SilentlyContinue |
            Sort-Object -Property Length -Descending |
            Select-Object -First 20

        if ($files) {
            Write-Host ""
            Write-Host "Top 20 maiores arquivos:" -ForegroundColor Cyan
            $files | ForEach-Object {
                $rel = $_.FullName.Replace($profilePath, '~')
                Write-Host ("  {0,-60} {1}" -f $rel, (script:Format-FileSize $_.Length))
            }
        } else {
            Write-Host "Nenhum arquivo encontrado." -ForegroundColor Yellow
        }
    } catch {
        Write-Log -Message "Erro ao listar arquivos: $_" -Level "ERROR"
        Write-Host "Erro ao analisar arquivos do perfil." -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [3] Limpar temporarios do usuario
# ──────────────────────────────────────────

function Clear-UserTemp {
    Write-Log -Message "Iniciando limpeza de temporarios do usuario" -Level "INFO"

    if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
        Write-Host ""
        Write-Host "Limpeza real de temporarios e focada em Windows." -ForegroundColor Yellow
        Write-Host "No Linux, nenhuma acao foi realizada."
        return
    }

    $tempPath = $env:TEMP
    Write-Host ""
    Write-Host "Pasta de temporarios: $tempPath" -ForegroundColor Cyan

    if (-not (script:Confirm-Action "Limpar conteudo de $tempPath ?")) {
        Write-Log -Message "Limpeza de TEMP cancelada pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        $items = Get-ChildItem -Path $tempPath -ErrorAction SilentlyContinue
        $removed = 0; $skipped = 0
        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $removed++
            } catch {
                $skipped++
            }
        }
        Write-Log -Message "TEMP limpo: $removed removidos, $skipped em uso (ignorados)" -Level "INFO"
        Write-Host "Concluido: $removed itens removidos, $skipped em uso ignorados." -ForegroundColor Green
    } catch {
        Write-Log -Message "Erro na limpeza de TEMP: $_" -Level "ERROR"
        Write-Host "Erro durante a limpeza." -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [4] Limpar temporarios do Windows
# ──────────────────────────────────────────

function Clear-WindowsTemp {
    Write-Log -Message "Iniciando limpeza de C:\Windows\Temp" -Level "INFO"

    if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    if (-not (script:Test-IsAdmin)) {
        Write-Log -Message "Limpeza de Windows\Temp requer privilegios de administrador" -Level "WARN"
        Write-Host ""
        Write-Host "Execute o Atlas como Administrador para usar esta funcao." -ForegroundColor Yellow
        return
    }

    $winTemp = "$env:SystemRoot\Temp"
    Write-Host ""
    Write-Host "Pasta: $winTemp" -ForegroundColor Cyan

    if (-not (script:Confirm-Action "Limpar conteudo de $winTemp ?")) {
        Write-Log -Message "Limpeza de Windows\Temp cancelada pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        $items = Get-ChildItem -Path $winTemp -ErrorAction SilentlyContinue
        $removed = 0; $skipped = 0
        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $removed++
            } catch {
                $skipped++
            }
        }
        Write-Log -Message "Windows\Temp limpo: $removed removidos, $skipped em uso (ignorados)" -Level "INFO"
        Write-Host "Concluido: $removed itens removidos, $skipped em uso ignorados." -ForegroundColor Green
    } catch {
        Write-Log -Message "Erro na limpeza de Windows\Temp: $_" -Level "ERROR"
        Write-Host "Erro durante a limpeza." -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [5] Limpar cache do Windows Update
# ──────────────────────────────────────────

function Clear-WindowsUpdateCache {
    Write-Log -Message "Iniciando limpeza do cache do Windows Update" -Level "INFO"

    if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    if (-not (script:Test-IsAdmin)) {
        Write-Log -Message "Limpeza do Windows Update requer privilegios de administrador" -Level "WARN"
        Write-Host ""
        Write-Host "Execute o Atlas como Administrador para usar esta funcao." -ForegroundColor Yellow
        return
    }

    $downloadPath = "$env:SystemRoot\SoftwareDistribution\Download"
    Write-Host ""
    Write-Host "Pasta: $downloadPath" -ForegroundColor Cyan
    Write-Host "Os servicos wuauserv e BITS serao parados temporariamente." -ForegroundColor Gray

    if (-not (script:Confirm-Action "Limpar cache do Windows Update em $downloadPath ?")) {
        Write-Log -Message "Limpeza do Windows Update cancelada pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Write-Host "Parando servicos..." -ForegroundColor Gray
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name BITS    -Force -ErrorAction SilentlyContinue

        $items = Get-ChildItem -Path $downloadPath -ErrorAction SilentlyContinue
        $removed = 0; $skipped = 0
        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $removed++
            } catch {
                $skipped++
            }
        }

        Write-Host "Reiniciando servicos..." -ForegroundColor Gray
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Start-Service -Name BITS    -ErrorAction SilentlyContinue

        Write-Log -Message "Cache WU limpo: $removed removidos, $skipped ignorados" -Level "INFO"
        Write-Host "Concluido: $removed itens removidos, $skipped ignorados." -ForegroundColor Green
    } catch {
        # Tentar restartar servicos mesmo em caso de erro
        try { Start-Service -Name wuauserv -ErrorAction SilentlyContinue } catch { }
        try { Start-Service -Name BITS    -ErrorAction SilentlyContinue } catch { }
        Write-Log -Message "Erro na limpeza do Windows Update: $_" -Level "ERROR"
        Write-Host "Erro durante a limpeza. Servicos reiniciados." -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [6] Esvaziar lixeira
# ──────────────────────────────────────────

function Clear-RecycleBinSafe {
    Write-Log -Message "Iniciando esvaziamento da lixeira" -Level "INFO"

    if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
        Write-Host ""
        Write-Host "Funcao disponivel apenas no Windows." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Esta acao ira esvaziar permanentemente a Lixeira." -ForegroundColor Cyan

    if (-not (script:Confirm-Action "Esvaziar a Lixeira?")) {
        Write-Log -Message "Esvaziamento da lixeira cancelado pelo usuario" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Log -Message "Lixeira esvaziada com sucesso" -Level "INFO"
        Write-Host "Lixeira esvaziada com sucesso." -ForegroundColor Green
    } catch {
        Write-Log -Message "Erro ao esvaziar lixeira: $_" -Level "ERROR"
        Write-Host "Erro ao esvaziar a lixeira." -ForegroundColor Red
    }
}

# ──────────────────────────────────────────
# [7] Limpeza segura completa
# ──────────────────────────────────────────

function Invoke-SafeCleanup {
    Write-Log -Message "Iniciando limpeza segura completa" -Level "INFO"
    Write-Host ""
    Write-Host "Limpeza segura completa" -ForegroundColor Cyan
    Write-Host "Cada etapa pedira confirmacao separada." -ForegroundColor Gray
    Write-Host "Cache do Windows Update NAO sera incluido automaticamente." -ForegroundColor Gray

    Write-Host ""
    Write-Host "--- Etapa 1/3: Temporarios do usuario ---" -ForegroundColor DarkCyan
    Clear-UserTemp

    Write-Host ""
    Write-Host "--- Etapa 2/3: Temporarios do Windows ---" -ForegroundColor DarkCyan
    Clear-WindowsTemp

    Write-Host ""
    Write-Host "--- Etapa 3/3: Lixeira ---" -ForegroundColor DarkCyan
    Clear-RecycleBinSafe

    Write-Log -Message "Limpeza segura completa encerrada" -Level "INFO"
    Write-Host ""
    Write-Host "Limpeza concluida." -ForegroundColor Green
}

# ──────────────────────────────────────────
# Menu de limpeza
# ──────────────────────────────────────────

function Show-CleanupMenu {
    $cleanRunning = $true

    while ($cleanRunning) {
        Clear-Host
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  Atlas - Limpeza Segura" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[1]  Ver maiores pastas do perfil"
        Write-Host "     Analisa D:\Users para encontrar pasta mais pesada"
        Write-Host ""
        Write-Host "[2]  Ver maiores arquivos do perfil"
        Write-Host "     Lista arquivos individuais acima de 50MB"
        Write-Host ""
        Write-Host "[3]  Limpar temporarios do usuario"
        Write-Host "     Remove %TEMP% e AppData\Local\Temp (seguro)"
        Write-Host ""
        Write-Host "[4]  Limpar temporarios do Windows"
        Write-Host "     Limpa C:\Windows\Temp sem afetar sistema"
        Write-Host ""
        Write-Host "[5]  Limpar cache do Windows Update"
        Write-Host "     Remove arquivos baixados ja instalados"
        Write-Host ""
        Write-Host "[6]  Esvaziar lixeira"
        Write-Host "     Permanentemente remove arquivos deletados"
        Write-Host ""
        Write-Host "[7]  Limpeza segura completa"
        Write-Host "     Executa 1-6 em sequencia (requer confirmacao)"
        Write-Host ""
        Write-Host "[0]  Voltar"
        Write-Host ""

        $opt = Read-Host "Escolha uma opcao"

        switch ($opt) {
            "1" { Get-LargestUserFolders;    Wait-UserInput }
            "2" { Get-LargestUserFiles;       Wait-UserInput }
            "3" { Clear-UserTemp;             Wait-UserInput }
            "4" { Clear-WindowsTemp;          Wait-UserInput }
            "5" { Clear-WindowsUpdateCache;   Wait-UserInput }
            "6" { Clear-RecycleBinSafe;       Wait-UserInput }
            "7" {
                Write-Host ""
                Write-Host "AVISO: Limpeza Segura Completa" -ForegroundColor Yellow
                Write-Host "Sera removido:" -ForegroundColor Yellow
                Write-Host "  - Temporarios do usuario" -ForegroundColor Gray
                Write-Host "  - Temporarios do Windows" -ForegroundColor Gray
                Write-Host "  - Cache Windows Update" -ForegroundColor Gray
                Write-Host "  - Lixeira" -ForegroundColor Gray
                Write-Host "" -ForegroundColor Yellow
                Write-Host "NAO sera removido:" -ForegroundColor Yellow
                Write-Host "  - Documentos, Downloads, Fotos, Desktop" -ForegroundColor Gray
                Write-Host "  - Arquivos pessoais ou programas" -ForegroundColor Gray
                Write-Host "  - Senhas ou configuracoes" -ForegroundColor Gray
                Write-Host "" -ForegroundColor Yellow
                $confirm = Read-Host "Continuar? (s/N)"
                if ($confirm -match '^[sS]$') {
                    Invoke-SafeCleanup
                }
                Wait-UserInput
            }
            "0" {
                Write-Log -Message "Saindo do menu de limpeza" -Level "INFO"
                $cleanRunning = $false
            }
            default {
                Write-Log -Message "Opcao invalida no menu de limpeza: $opt" -Level "WARN"
                Write-Host "Opcao invalida." -ForegroundColor Yellow
                Wait-UserInput
            }
        }
    }
}
