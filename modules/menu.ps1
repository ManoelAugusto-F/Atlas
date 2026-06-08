function Show-MainMenu {

    Show-AtlasHeader

    Show-AtlasCompactOption -Number "1" -Name "Limpeza segura"
    Show-AtlasCompactOption -Number "2" -Name "Rede e internet"
    Show-AtlasCompactOption -Number "3" -Name "OneDrive"
    Show-AtlasCompactOption -Number "4" -Name "Impressoras"
    Show-AtlasCompactOption -Number "5" -Name "Reparos Windows"
    Show-AtlasCompactOption -Number "6" -Name "Outlook"
    Show-AtlasCompactOption -Number "7" -Name "Teams"
    Show-AtlasCompactOption -Number "8" -Name "Navegadores"
    Show-AtlasCompactOption -Number "9" -Name "Instalacao de programas"
    Show-AtlasCompactOption -Number "10" -Name "Historico do Atlas"

    Show-AtlasBackOption -Label "Sair"
}
