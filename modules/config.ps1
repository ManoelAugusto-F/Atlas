function Get-AppCatalog {

    $configPath = Join-Path $PSScriptRoot "../config/apps.json"

    if (-not (Test-Path $configPath)) {
        Write-Host "ERRO: Arquivo de catalogo nao encontrado: $configPath" -ForegroundColor Red
        return $null
    }

    try {
        $content = Get-Content $configPath -Raw -ErrorAction Stop
        return $content | ConvertFrom-Json
    }
    catch {
        Write-Host "ERRO: Falha ao ler o catalogo de aplicacoes: $_" -ForegroundColor Red
        return $null
    }
}