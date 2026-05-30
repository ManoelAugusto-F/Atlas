function Show-MainMenu {

    Clear-Host

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " Atlas" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[1]  Informacoes do sistema"
    Write-Host "[2]  Informacoes de rede"
    Write-Host "[3]  Testar internet e DNS"
    Write-Host "[4]  Limpar temporarios do usuario"
    Write-Host "[5]  Listar servicos parados importantes"
    Write-Host "[6]  Ver uso de disco"
    Write-Host "[7]  Ver ultimo boot"
    Write-Host "[8]  Diagnostico rapido da maquina"
    Write-Host "[9]  Verificar saude de rede corporativa"
    Write-Host "[10] Verificar servicos essenciais"
    Write-Host "[11] Verificar disco e pastas pesadas"
    Write-Host "[12] Verificar updates e reboot pendente"
    Write-Host "[13] Verificar seguranca basica"
    Write-Host "[14] Coletar evidencias para atendimento"
    Write-Host "[15] Inventario completo"
    Write-Host "[16] Diagnostico corporativo de rede"
    Write-Host "[0]  Sair"
    Write-Host ""
}