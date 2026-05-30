# ==========================================
# Atlas — Funcoes utilitarias centrais
# ==========================================

function Show-FeaturePlaceholder {
    param([string]$FeatureName)

    Write-Log -Message "Funcionalidade acessada: $FeatureName" -Level "INFO"
    Write-Host ""
    Write-Host "Funcionalidade em desenvolvimento: $FeatureName" -ForegroundColor Yellow
    Write-Host "Nenhuma alteracao foi feita no sistema."
}

function Wait-UserInput {
    Write-Host ""
    Read-Host "Pressione Enter para continuar"
}
