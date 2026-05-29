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
    Write-Host $env:USER
}

function Get-SystemInformation {

    Write-Host ""
    Write-Host "Hostname:"
    hostname

    Write-Host ""
    Write-Host "Kernel:"
    uname -r

    Write-Host ""
    Write-Host "Arquitetura:"
    uname -m
}