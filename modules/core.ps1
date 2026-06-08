# ==========================================
# Atlas — Funcoes utilitarias centrais
# ==========================================

function Show-FeaturePlaceholder {
    param([string]$FeatureName)

    Write-Log -Message "Funcionalidade acessada: $FeatureName" -Level "INFO"
    Write-Host ""
    Write-Host "Funcionalidade em desenvolvimento: $FeatureName" -ForegroundColor Yellow
    Write-Host "Nenhuma alteracao foi feita no sistema." -ForegroundColor White
}

function Wait-UserInput {
    Write-Host ""
    Write-Host "Pressione Enter para continuar" -ForegroundColor Magenta
    Read-Host | Out-Null
}

function Show-AtlasMenuHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Clear-Host
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Atlas - $Title" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-AtlasMenuOption {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Number,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$Description,
        [ValidateSet("nenhum", "baixo", "medio", "alto", "")]
        [string]$Risk = ""
    )

    Write-Host "[$Number] $Name" -ForegroundColor White

    $line = $Description
    if ($Risk) {
        $riskLabel = switch ($Risk) {
            "nenhum" { "sem risco" }
            "baixo"  { "baixo risco" }
            "medio"  { "medio risco" }
            "alto"   { "alto risco" }
        }
        if ($line) {
            $line = "$line ($riskLabel)"
        } else {
            $line = $riskLabel
        }
    }

    if ($line) {
        Write-Host "    $line" -ForegroundColor White
    }

    Write-Host ""
}

function Show-AtlasMenuBackOption {
    Write-Host "[0] Voltar" -ForegroundColor White
    Write-Host ""
}

function Read-AtlasMenuChoice {
    Write-Host "Escolha uma opcao: " -NoNewline -ForegroundColor Magenta
    return Read-Host
}

function Write-AtlasInfo {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor White
}

function Write-AtlasSuccess {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-AtlasWarning {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-AtlasError {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Read-AtlasConfirm {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ""
    Write-Host $Message -ForegroundColor Magenta
    return Read-Host "Confirmar? (s/N)"
}
