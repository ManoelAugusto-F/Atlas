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
    Write-Host "[8]  Ver processos que mais usam CPU"
    Write-Host "[9]  Ver processos que mais usam memoria"
    Write-Host "[10] Testar portas comuns"
    Write-Host "[11] Ver eventos recentes de erro"
    Write-Host "[12] Ver atualizacoes instaladas"
    Write-Host "[13] Ver status do Defender"
    Write-Host "[14] Gerar relatorio TXT"
    Write-Host "[0]  Sair"
    Write-Host ""
}