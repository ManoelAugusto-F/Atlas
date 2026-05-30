. "$PSScriptRoot/../modules/logger.ps1"
. "$PSScriptRoot/../modules/core.ps1"
. "$PSScriptRoot/../modules/menu.ps1"

$running = $true
$inputs  = @('1','2','3','4','5','6','7','99','0')
$idx     = 0

while ($running) {
    $option = $inputs[$idx]; $idx++
    Write-Host ""
    Write-Host "========================================" -ForegroundColor DarkCyan
    Write-Host "[TESTE] Opcao simulada: $option" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor DarkCyan

    switch ($option) {
        '1'  { Show-FeaturePlaceholder -FeatureName "Diagnostico rapido" }
        '2'  { Show-FeaturePlaceholder -FeatureName "Limpeza segura" }
        '3'  { Show-FeaturePlaceholder -FeatureName "Rede e internet" }
        '4'  { Show-FeaturePlaceholder -FeatureName "OneDrive" }
        '5'  { Show-FeaturePlaceholder -FeatureName "Impressoras" }
        '6'  { Show-FeaturePlaceholder -FeatureName "Reparos Windows" }
        '7'  { Show-FeaturePlaceholder -FeatureName "Relatorio de suporte" }
        '0'  { Write-Log -Message "Atlas encerrado" -Level "INFO"; $running = $false }
        default {
            Write-Log -Message "Opcao invalida: $option" -Level "WARN"
            Write-Host "Opcao invalida." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "LOOP ENCERRADO COM SUCESSO" -ForegroundColor Green
