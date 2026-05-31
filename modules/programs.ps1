# Programs Toolkit - Modulo Atlas para Inventario de Software Instalado
# Valido e higienizado para uso em Windows PowerShell 5.1 e 7+
# Codificacao estrita: ASCII puro

$Global:AtlasLoadedModules = $Global:AtlasLoadedModules | Where-Object { $_ -ne "Programs" }
$Global:AtlasLoadedModules += "Programs"

function Get-InstalledPrograms {
    <#
    .SYNOPSIS
        Obtem uma lista de programas instalados no sistema consultando o registro.
    .DESCRIPTION
        Consulta chaves HKLM e HKCU "Uninstall" tanto para softwares 32-bit quanto 64-bit.
    .OUTPUTS
        Array de PSCustomObject contendo Nome, Versao, Desenvolvedor e Caminho de desinstalacao.
    #>
    [CmdletBinding()]
    param()

    Write-Log -Level "INFO" -Message "Listando programas instalados no registro do Windows..."
    $programs = @()

    if (!($IsWindows) -and !($env:OS -like "*Windows*")) {
        Write-Log -Level "WARN" -Message "Navegacao em Registro desabilitada em sistemas nao-Windows."
        return $programs
    }

    # Chaves conhecidas de desinstalacao de programas
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            try {
                $subKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                foreach ($key in $subKeys) {
                    try {
                        $prop = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                        if ($prop -and $prop.DisplayName) {
                            $name = $prop.DisplayName
                            $version = if ($prop.DisplayVersion) { $prop.DisplayVersion } else { "N/A" }
                            $publisher = if ($prop.Publisher) { $prop.Publisher } else { "N/A" }
                            $uninstallString = if ($prop.UninstallString) { $prop.UninstallString } else { "N/A" }

                            # Evita duplicados na lista pela chave primaria do nome do programa
                            $isDupe = $false
                            foreach ($p in $programs) {
                                if ($p.Name -eq $name) {
                                    $isDupe = $true
                                    break
                                }
                            }

                            if (!($isDupe)) {
                                $programs += [PSCustomObject]@{
                                    Name            = $name
                                    Version         = $version
                                    Publisher       = $publisher
                                    UninstallString = $uninstallString
                                }
                            }
                        }
                    } catch {}
                }
            } catch {
                Write-Log -Level "WARN" -Message "Nao foi possivel acessar a chave de Registro: $path"
            }
        }
    }

    # Ordena pelo nome do programa para facilitar leitura
    $sortedPrograms = $programs | Sort-Object Name
    Write-Log -Level "INFO" -Message "Mapeamento do registro concluido. Total de programas encontrados: $($sortedPrograms.Count)"
    return $sortedPrograms
}

function Export-InstalledProgramsCsv {
    <#
    .SYNOPSIS
        Gera e exporta a lista de programas instalados para um arquivo CSV unificado.
    .PARAMETER OutputPath
        Caminho do arquivo de destino. Padrao: "reports/programs.csv".
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = "reports/programs.csv"
    )

    Write-Log -Level "INFO" -Message "Solicitada exportacao de relatorio de softwares instalados..."

    # Garante a existencia da pasta pai
    $parentDir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if ($parentDir -and !(Test-Path $parentDir)) {
        try {
            New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }

    $progs = Get-InstalledPrograms
    if ($progs.Count -eq 0) {
        Write-Log -Level "WARN" -Message "Nenhum programa localizado para exportacao."
        return $false
    }

    try {
        # Converte para CSV sem type information e com delimitador padrao de virgula, forcando ASCII para compatibilidade total
        $progs | Export-Csv -Path $OutputPath -NoTypeInformation -Force -Encoding ASCII
        Write-Log -Level "INFO" -Message "Arquivo CSV de programas gerado com sucesso em: $OutputPath"
        return $true
    } catch {
        Write-Log -Level "ERROR" -Message "Falha ao gravar arquivo CSV de programas: $($_.Exception.Message)"
        return $false
    }
}
