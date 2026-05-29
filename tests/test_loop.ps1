. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/system.ps1"
. "$PSScriptRoot/../modules/menu.ps1"
. "$PSScriptRoot/../modules/config.ps1"

$running = $true
$inputs = @('1', '2', '3', '9', '0')
$idx = 0

while ($running) {
    $option = $inputs[$idx]; $idx++
    Write-Host "[TESTE] Opcao simulada: $option" -ForegroundColor Magenta

    switch ($option) {
        '1' {
            Write-Log -Message "Usuario executou verificacao de ambiente" -Level "INFO"
            Get-SystemEnvironment
        }
        '2' {
            Write-Log -Message "Usuario executou informacoes do sistema" -Level "INFO"
            Get-SystemInformation
        }
        '3' {
            Write-Log -Message "Usuario listou catalogo de aplicacoes" -Level "INFO"
            $catalog = Get-AppCatalog
            $catalog.apps | Format-Table name, manager, id -AutoSize
        }
        '0' {
            Write-Log -Message "InfraForge encerrado" -Level "INFO"
            $running = $false
        }
        default {
            Write-Log -Message "Opcao invalida selecionada: $option" -Level "WARN"
            Write-Host "Opcao invalida." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "LOOP ENCERRADO COM SUCESSO" -ForegroundColor Green
