function Test-IsWindows {
    return $PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows -eq $true
}

function Test-IsLinux {
    return $IsLinux -eq $true
}

function Wait-UserInput {
    Write-Host ""
    Write-Host "Pressione Enter para continuar..." -ForegroundColor DarkGray
    $null = Read-Host
}

function Get-SystemEnvironment {

    Write-Host ""
    Write-Host "Verificando ambiente..." -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Sistema operacional:"
    Write-Host $PSVersionTable.OS

    Write-Host ""
    Write-Host "Versao PowerShell:"
    Write-Host $PSVersionTable.PSVersion

    Write-Host ""
    Write-Host "Usuario atual:"
    if (Test-IsWindows) {
        Write-Host $env:USERNAME
    } else {
        Write-Host $env:USER
    }

    Write-Log -Message "Get-SystemEnvironment executado" -Level "INFO"
}

function Get-SystemInformation {

    Write-Host ""
    Write-Host "Informacoes do sistema:" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Hostname:"
    Write-Host ([System.Net.Dns]::GetHostName())

    Write-Host ""
    Write-Host "Sistema:"
    Write-Host $PSVersionTable.OS

    Write-Host ""
    Write-Host "Arquitetura:"
    Write-Host ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)

    if (Test-IsLinux) {
        Write-Host ""
        Write-Host "Kernel:"
        $kernel = & uname -r 2>$null
        if ($kernel) { Write-Host $kernel }
    }

    Write-Log -Message "Get-SystemInformation executado" -Level "INFO"
}

function Get-InstalledUpdates {

    Write-Host ""
    Write-Host "Atualizacoes instaladas:" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Host "No Linux, use 'apt list --installed' ou o gerenciador de pacotes do sistema."
        Write-Log -Message "Get-InstalledUpdates chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    try {
        $hotfixes = Get-HotFix -ErrorAction Stop |
            Sort-Object InstalledOn -Descending |
            Select-Object -First 20

        if ($hotfixes) {
            $hotfixes | ForEach-Object {
                [PSCustomObject]@{
                    ID          = $_.HotFixID
                    Tipo        = $_.Description
                    InstalladoEm = if ($_.InstalledOn) { $_.InstalledOn.ToString('dd/MM/yyyy') } else { 'N/A' }
                }
            } | Format-Table ID, Tipo, InstalladoEm -AutoSize
        }
        else {
            Write-Host "Nenhuma atualizacao encontrada." -ForegroundColor DarkGray
        }

        Write-Log -Message "Get-InstalledUpdates executado. Hotfixes: $($hotfixes.Count)" -Level "INFO"
    }
    catch {
        Write-Host "Erro ao obter atualizacoes: $_" -ForegroundColor Red
        Write-Log -Message "Erro em Get-InstalledUpdates: $_" -Level "ERROR"
    }
}