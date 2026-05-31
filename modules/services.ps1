# Services Toolkit - Modulo Atlas para Automacao de Servicos Windows
# Higienizado com codificacao ASCII puro para Windows PowerShell 5.1 e 7+

$Global:AtlasLoadedModules = $Global:AtlasLoadedModules | Where-Object { $_ -ne "Services" }
$Global:AtlasLoadedModules += "Services"

function Get-CriticalServices {
    <#
    .SYNOPSIS
        Analisa e retorna dados de saude de servicos de rede e servicos corporativos estruturais.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Buscando status de servicos corporativos estruturais do Windows..."
    $results = @()

    if (!($IsWindows) -and !($env:OS -like "*Windows*")) {
        Write-Log -Level "WARN" -Message "O servico de consulta de servicos do Windows (WMI/CIM/ServiceController) nao esta disponivel fora do Windows."
        return $results
    }

    # Lista de servicos corporativos vitais
    $servicesToCheck = @("Dhcp", "Dnscache", "gpsvc", "Spooler", "LanmanWorkstation", "Wuauserv")

    foreach ($srvName in $servicesToCheck) {
        try {
            $srv = Get-Service -Name $srvName -ErrorAction SilentlyContinue
            if ($srv) {
                # Obtem modo de inicializacao padrao de forma segura
                $startType = "N/A"
                if (Get-Command "Get-CimInstance" -ErrorAction SilentlyContinue) {
                    try {
                        $cimSrv = Get-CimInstance -ClassName Win32_Service -Filter "Name='$srvName'" -ErrorAction SilentlyContinue
                        if ($cimSrv) { $startType = $cimSrv.StartMode }
                    } catch {}
                }

                $results += [PSCustomObject]@{
                    ServiceName = $srv.Name
                    DisplayName = $srv.DisplayName
                    Status      = $srv.Status.ToString()
                    StartType   = $startType
                }
            } else {
                $results += [PSCustomObject]@{
                    ServiceName = $srvName
                    DisplayName = "N/A (Nao localizado)"
                    Status      = "Missing"
                    StartType   = "N/A"
                }
            }
        } catch {
            Write-Log -Level "WARN" -Message "Erro ao consultar status do servico: $srvName"
        }
    }

    return $results
}

function Get-StoppedAutomaticServices {
    <#
    .SYNOPSIS
        Detecta servicos configurados para inicializacao automatica mas que encontram-se indevidamente parados.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Varrendo o sistema por servicos com inicio automatico indevidamente parados..."
    $issues = @()

    if (!($IsWindows) -and !($env:OS -like "*Windows*")) {
        Write-Log -Level "WARN" -Message "Consulta de servicos parados ignorada fora do Windows."
        return $issues
    }

    if (Get-Command "Get-CimInstance" -ErrorAction SilentlyContinue) {
        try {
            # Filtro do WMI/CIM: StartMode = 'Auto' and State != 'Running'
            # Evita serviços que possuem padrões como trigger-start ou atrasados se possível,
            # mas o filtro basico ja entrega os itens criticos
            $stoppedAuto = Get-CimInstance -ClassName Win32_Service -Filter "StartMode='Auto' and State!='Running'" -ErrorAction SilentlyContinue
            foreach ($s in $stoppedAuto) {
                # Algumas excecoes comuns do propro sistema do Windows de servicos que desligam se sem uso ativo:
                $ignoreList = @("gupdate", "MapsBroker", "EdgeUpdate", "RemoteRegistry", "sppsvc", "ShellHWDetection")
                if ($ignoreList -notcontains $s.Name) {
                    $issues += [PSCustomObject]@{
                        ServiceName = $s.Name
                        DisplayName = $s.DisplayName
                        State       = $s.State
                        StartMode   = $s.StartMode
                    }
                }
            }
        } catch {
            Write-Log -Level "ERROR" -Message "Erro ao varrer servicos utilizando CimInstance: $($_.Exception.Message)"
        }
    } else {
        # Fallback utilizando o Get-Service legado do PowerShell 2.0/5.1
        try {
            $services = Get-Service | Where-Object { $_.Status -eq "Stopped" }
            foreach ($s in $services) {
                # Pega propriedades extras que podem nao estar expostas diretamente no PS 5.1 sem CIM
                if ($s.StartType -eq "Automatic") {
                    $issues += [PSCustomObject]@{
                        ServiceName = $s.ServiceName
                        DisplayName = $s.DisplayName
                        State       = "Stopped"
                        StartMode   = "Automatic"
                    }
                }
            }
        } catch {}
    }

    Write-Log -Level "INFO" -Message "Busca concluida. Total de servicos automaticos parados encontrados: $($issues.Count)"
    return $issues
}

function Restart-ServiceSafe {
    <#
    .SYNOPSIS
        Tenta reiniciar de forma unificada e assistida um servico do Windows.
    .PARAMETER ServiceName
        Nome interno simplificado do servico. Se for informado de forma invalida, retorna falha.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )

    Write-Log -Level "INFO" -Message "Tentativa de reinicializacao assistida do servico: $ServiceName"

    if (!($IsWindows) -and !($env:OS -like "*Windows*")) {
        Write-Log -Level "WARN" -Message "Modificacao de servicos negada fora do Windows."
        return $false
    }

    $srv = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (!($srv)) {
        Write-Log -Level "ERROR" -Message "Servico $ServiceName nao localizado na maquina."
        return $false
    }

    try {
        Write-Log -Level "INFO" -Message "Executando comando de reinicio para o servico: $ServiceName..."
        Restart-Service -Name $ServiceName -ErrorAction Stop
        # Loop curto para aguardar atualizacao de status
        for ($i = 0; $i -lt 5; $i++) {
            $srv = Get-Service -Name $ServiceName
            if ($srv.Status -eq "Running") {
                Write-Log -Level "INFO" -Message "Servico $ServiceName reiniciado com exito."
                return $true
            }
            Start-Sleep -Seconds 1
        }
    } catch {
        $errMsg = $_.Exception.Message
        Write-Log -Level "ERROR" -Message "Nao foi possivel reiniciar o servico $ServiceName. Erro: $errMsg"
    }

    return $false
}
