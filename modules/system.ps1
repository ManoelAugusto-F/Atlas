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
}