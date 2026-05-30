function Show-MainMenu {

    Clear-Host

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " Atlas" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[1] Informacoes do sistema"
    Write-Host "[2] Informacoes de rede"
    Write-Host "[3] Testar internet e DNS"
    Write-Host "[4] Limpar temporarios do usuario"
    Write-Host "[5] Listar servicos parados importantes"
    Write-Host "[6] Ver uso de disco"
    Write-Host "[7] Ver ultimo boot"
    Write-Host "[0] Sair"
    Write-Host ""
}