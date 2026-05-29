# ==========================================
# Provisionador PowerShell
# Bootstrap Principal
# ==========================================

# Carregar modulos

. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/system.ps1"
. "$PSScriptRoot/../modules/logger.ps1"

# Loop principal

do {

    Show-MainMenu

    $option = Read-Host "Escolha uma opcao"

    switch ($option) {

        "1" {

            Write-Log "Usuario executou verificacao de ambiente"

            Get-SystemEnvironment

            Pause
        }

        "2" {

            Write-Log "Usuario executou informacoes do sistema"

            Get-SystemInformation

            Pause
        }

        "0" {

            Write-Log "Provisionador encerrado"

            exit
        }

        default {

            Write-Host ""
            Write-Host "Opcao invalida." -ForegroundColor Red

            Pause
        }
    }

} while ($true)