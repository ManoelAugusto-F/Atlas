# Outlook Toolkit - Modulo Atlas para Automacao Microsoft Outlook
# Compatibilidade: Windows PowerShell 5.1 e PowerShell 7+
# Codificacao estrita: ASCII puro para evitar quebras de parser

# Garante que dependencias globais existam antes da execucao
$Global:AtlasLoadedModules = $Global:AtlasLoadedModules | Where-Object { $_ -ne "Outlook" }
$Global:AtlasLoadedModules += "Outlook"

function Get-OutlookStatus {
    <#
    .SYNOPSIS
        Verifica a instalacao e o status do Microsoft Outlook local.
    .DESCRIPTION
        Retorna se o Outlook esta instalado no registro, o status do processo
        e os caminhos padrao identificados.
    .OUTPUTS
        PSCustomObject com o status do Outlook.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Iniciante diagnostico do Microsoft Outlook..."

    # Inicializa variaveis padrao
    $installed = $false
    $procRunning = $false
    $outlookVersion = "N/A"
    $executablePath = "N/A"

    # Verifica se o processo esta em execucao
    try {
        $proc = Get-Process -Name "outlook" -ErrorAction SilentlyContinue
        if ($proc) {
            $procRunning = $true
            # Tenta pegar o caminho do executavel no Windows
            if ($IsWindows -or ($env:OS -like "*Windows*")) {
                try { $executablePath = $proc.Path } catch {}
            }
        }
    } catch {
        Write-Log -Level "WARN" -Message "Falha ao ler processos do Outlook."
    }

    # Se for Windows, podemos checar caminhos de registro e arquivos conhecidos
    if ($IsWindows -or ($env:OS -like "*Windows*")) {
        # Procurar caminhos de registro tipicos para o Office
        $regKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE",
            "HKLM:\SOFTWARE\Microsoft\Office\16.0\Outlook",
            "HKLM:\SOFTWARE\Microsoft\Office\15.0\Outlook"
        )
        foreach ($key in $regKeys) {
            if (Test-Path $key) {
                $installed = $true
                try {
                    if ($key -like "*App Paths*") {
                        $outlookPathVal = Get-ItemProperty -Path $key -Name "(Default)" -ErrorAction SilentlyContinue
                        if ($outlookPathVal) { $executablePath = $outlookPathVal."(Default)" }
                    }
                } catch {}
            }
        }

        # Deteccao por caminhos conhecidos de instalacao padrao se nao encontrado pelo registro
        if (!($installed) -and ($executablePath -eq "N/A")) {
            $paths = @(
                "$env:ProgramFiles\Microsoft Office\root\Office16\OUTLOOK.EXE",
                "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\OUTLOOK.EXE",
                "$env:ProgramFiles\Microsoft Office\Office16\OUTLOOK.EXE",
                "$env:ProgramFiles\Microsoft Office\Office15\OUTLOOK.EXE"
            )
            foreach ($p in $paths) {
                if (Test-Path $p) {
                    $installed = $true
                    $executablePath = $p
                    break
                }
            }
        }
    } else {
        # cross-platform mockup
        Write-Log -Level "INFO" -Message "Executando em ambiente nao-Windows. Retornando status simulado."
    }

    $ret = [PSCustomObject]@{
        Installed      = $installed
        ProcessRunning = $procRunning
        ExecutablePath = $executablePath
        OSPlatform     = if ($IsWindows -or ($env:OS -like "*Windows*")) { "Windows" } else { "Non-Windows" }
    }

    Write-Log -Level "INFO" -Message "Status do Outlook mapeado - Instalado: $installed, Em Execucao: $procRunning"
    return $ret
}

function Restart-OutlookProcess {
    <#
    .SYNOPSIS
        Reinicia o Microsoft Outlook de forma assistida.
    .DESCRIPTION
        Fecha de forma limpa ou forcada o Outlook e inicia uma nova instancia se rodando em Windows.
    .PARAMETER Force
        Se ativo, mata o processo imediatamente sem confirmacao.
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    $status = Get-OutlookStatus
    if (!($status.ProcessRunning)) {
        Write-Log -Level "WARN" -Message "Outlook nao esta em execucao. Nada para reiniciar."
        return $false
    }

    if (!($Force)) {
        Write-Host "Deseja realmente reiniciar o Microsoft Outlook? (S/N): " -NoNewline
        $ans = Read-Host
        if ($ans -notmatch "^[sS]") {
            Write-Log -Level "INFO" -Message "Reinicio do Outlook cancelado pelo usuario."
            return $false
        }
    }

    Write-Log -Level "INFO" -Message "Parando processo do MS Outlook..."
    try {
        Stop-Process -Name "outlook" -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
    } catch {
        Write-Log -Level "ERROR" -Message "Nao foi possivel parar o processo do Outlook: $($_.Exception.Message)"
        return $false
    }

    # Tenta reiniciar se o executavel foi detectado e estamos no Windows
    if (($status.ExecutablePath -and ($status.ExecutablePath -ne "N/A")) -and (Test-Path $status.ExecutablePath)) {
        Write-Log -Level "INFO" -Message "Obtido caminho do Outlook. Reiniciando o processo..."
        try {
            Start-Process -FilePath $status.ExecutablePath
            Write-Log -Level "INFO" -Message "Outlook iniciado com sucesso."
            return $true
        } catch {
            Write-Log -Level "ERROR" -Message "Falha ao iniciar processo Outlook: $($_.Exception.Message)"
        }
    } else {
        Write-Log -Level "WARN" -Message "Caminho do executavel indisponivel para reinicio automatico."
    }

    return $true
}

function Get-OutlookProfiles {
    <#
    .SYNOPSIS
        Procura perfis de email cadastrados do Microsoft Outlook.
    .DESCRIPTION
        Le perfis no Registro do Windows no caminho HKCU\Software\Microsoft\Office\16.0\Outlook\Profiles
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Pesquisando perfis do Outlook..."
    $profiles = @()

    if ($IsWindows -or ($env:OS -like "*Windows*")) {
        $regPaths = @(
            "HKCU:\Software\Microsoft\Office\15.0\Outlook\Profiles",
            "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles",
            "HKCU:\Software\Microsoft\Exchange\Client\Options"
        )
        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                try {
                    $keys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
                    foreach ($k in $keys) {
                        $profiles += $k.PSChildName
                    }
                } catch {
                    Write-Log -Level "WARN" -Message "Erro ao listar subchaves de registro de perfis."
                }
            }
        }
    } else {
        Write-Log -Level "INFO" -Message "Recurso de busca de perfis via registro nao suportado neste SO."
    }

    if ($profiles.Count -eq 0) {
        Write-Log -Level "INFO" -Message "Nenhum perfil de Outlook encontrado."
    } else {
        Write-Log -Level "INFO" -Message "Perfeis encontrados: $($profiles -join ', ')"
    }

    return $profiles
}
