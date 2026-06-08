function Show-MainMenu {

    Show-AtlasMenuHeader -Title "Assistente de Manutencao Windows"

    Show-AtlasMenuOption -Number "1" -Name "Limpeza segura" `
        -Description "Remove temporarios e libera espaco no disco" -Risk "baixo"
    Show-AtlasMenuOption -Number "2" -Name "Rede e internet" `
        -Description "Diagnostica e corrige problemas de conexao" -Risk "baixo"
    Show-AtlasMenuOption -Number "3" -Name "OneDrive" `
        -Description "Reinicia, repara ou reinstala o OneDrive" -Risk "baixo"
    Show-AtlasMenuOption -Number "4" -Name "Impressoras" `
        -Description "Corrige filas e servicos de impressao" -Risk "baixo"
    Show-AtlasMenuOption -Number "5" -Name "Reparos Windows" `
        -Description "Diagnostica e repara problemas do sistema" -Risk "medio"
    Show-AtlasMenuOption -Number "6" -Name "Outlook" `
        -Description "Corrige e-mails, cache e perfis do Outlook" -Risk "baixo"
    Show-AtlasMenuOption -Number "7" -Name "Teams" `
        -Description "Reinicia e limpa cache do Microsoft Teams" -Risk "baixo"
    Show-AtlasMenuOption -Number "8" -Name "Navegadores" `
        -Description "Limpa cache do Chrome, Edge e Firefox" -Risk "baixo"
    Show-AtlasMenuOption -Number "9" -Name "Instalacao de programas" `
        -Description "Instala softwares comuns via Winget" -Risk "medio"
    Show-AtlasMenuOption -Number "10" -Name "Historico do Atlas" `
        -Description "Consulta acoes realizadas neste computador" -Risk "nenhum"

    Write-Host "[0] Sair" -ForegroundColor White
    Write-Host ""
}
