# ==========================================
# Atlas — Funcoes utilitarias centrais
# ==========================================

$script:AtlasMenuWidth = 42

function Get-AtlasVersion {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $versionFile = Join-Path $repoRoot "version.txt"

    if (Test-Path $versionFile) {
        $raw = (Get-Content -Path $versionFile -TotalCount 1 -ErrorAction SilentlyContinue)
        if ($raw -and $raw.Trim() -match '^v\d+\.\d+\.\d+') {
            return $raw.Trim()
        }
    }

    $versionMd = Join-Path $repoRoot "VERSION.md"
    if (Test-Path $versionMd) {
        $line = Get-Content -Path $versionMd -TotalCount 1 -ErrorAction SilentlyContinue
        if ($line -match '(v\d+\.\d+\.\d+)') {
            return $Matches[1]
        }
    }

    return "v0.0.0"
}

function Test-AtlasAdmin {
    if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
        return $false
    }

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Show-FeaturePlaceholder {
    param([string]$FeatureName)

    Write-Log -Message "Funcionalidade acessada: $FeatureName" -Level "INFO"
    Write-Host ""
    Write-Host "Funcionalidade em desenvolvimento: $FeatureName" -ForegroundColor Yellow
    Write-Host "Nenhuma alteracao foi feita no sistema." -ForegroundColor White
}

function Wait-UserInput {
    Write-Host ""
    Write-Host "Pressione Enter para continuar" -ForegroundColor White
    Read-Host | Out-Null
}

function Format-AtlasCenteredText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [int]$Width = $script:AtlasMenuWidth
    )

    if ($Text.Length -ge $Width) {
        return $Text.Substring(0, $Width)
    }

    $pad = $Width - $Text.Length
    $left = [math]::Floor($pad / 2)
    return (' ' * $left) + $Text
}

function Show-AtlasHeader {
    param(
        [string]$Title
    )

    Clear-Host
    Write-Host ""
    $bar = '=' * $script:AtlasMenuWidth
    Write-Host $bar -ForegroundColor Cyan

    if ($Title) {
        $headerText = "ATLAS - $($Title.ToUpper())"
    } else {
        $headerText = "Atlas $(Get-AtlasVersion)"
    }

    Write-Host (Format-AtlasCenteredText -Text $headerText) -ForegroundColor Cyan
    Write-Host $bar -ForegroundColor Cyan

    if (-not $Title) {
        $adminLabel = if (Test-AtlasAdmin) { 'SIM' } else { 'NAO' }
        Write-Host (Format-AtlasCenteredText -Text "Administrador: $adminLabel") -ForegroundColor Gray
    }

    Write-Host ""
}

function Show-AtlasCompactOption {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Number,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $numberLabel = "[{0,2}] " -f $Number
    Write-Host -NoNewline $numberLabel -ForegroundColor Yellow
    Write-Host $Name -ForegroundColor White
}

function Show-AtlasDescribedOption {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Number,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $numberLabel = "[{0,2}] " -f $Number
    Write-Host -NoNewline $numberLabel -ForegroundColor Yellow
    Write-Host $Name -ForegroundColor White
    Write-Host "     $Description" -ForegroundColor White
    Write-Host ""
}

function Show-AtlasBackOption {
    param(
        [string]$Label = "Voltar"
    )

    Write-Host ""
    Write-Host -NoNewline ' [0] ' -ForegroundColor Yellow
    Write-Host $Label -ForegroundColor White
    Write-Host ""
}

function Read-AtlasMenuChoice {
    Write-Host "Escolha uma opcao:" -ForegroundColor White
    return Read-Host
}

function Show-AtlasMenuHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Show-AtlasHeader -Title $Title
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

    if ($Description) {
        Show-AtlasDescribedOption -Number $Number -Name $Name -Description $Description
    } else {
        Show-AtlasCompactOption -Number $Number -Name $Name
    }
}

function Show-AtlasMenuBackOption {
    param(
        [string]$Label = "Voltar"
    )

    Show-AtlasBackOption -Label $Label
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
    Write-Host $Message -ForegroundColor White
    return Read-Host "Confirmar? (s/N)"
}

function Write-AtlasStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "[INFO] " -NoNewline -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor White
}

function Write-AtlasProgress {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[INFO] " -NoNewline -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor White
}

function Write-AtlasResult {
    param(
        [ValidateSet('SUCESSO', 'FALHA', 'AVISO')]
        [string]$Status = 'SUCESSO',
        [string]$Message = ''
    )

    $color = switch ($Status) {
        'SUCESSO' { 'Green' }
        'FALHA'   { 'Red' }
        'AVISO'   { 'Yellow' }
    }

    Write-Host ""
    Write-Host ('=' * $script:AtlasMenuWidth) -ForegroundColor Cyan
    if ($Message) {
        Write-Host "Resultado: $Status - $Message" -ForegroundColor $color
    } else {
        Write-Host "Resultado: $Status" -ForegroundColor $color
    }
    Write-Host ('=' * $script:AtlasMenuWidth) -ForegroundColor Cyan
}
