# Atlas Online Bootstrap
# Baixa o Atlas para TEMP, executa e remove os arquivos ao sair.

$ErrorActionPreference = "Stop"

$AtlasZipUrl = "https://github.com/ManoelAugusto-F/Atlas/archive/refs/heads/main.zip"

function Clear-OldAtlasTempFolders {
    param(
        [string]$ExcludePath = $null
    )

    try {
        if (-not $env:TEMP -or -not (Test-Path $env:TEMP)) {
            return
        }

        $cutoff = (Get-Date).AddHours(-24)
        $oldFolders = Get-ChildItem -Path $env:TEMP -Directory -Filter 'Atlas_*' -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -ne $ExcludePath -and $_.LastWriteTime -lt $cutoff
            }

        if (-not $oldFolders) {
            return
        }

        Write-Host "Limpando execucoes antigas do Atlas..." -ForegroundColor Gray
        foreach ($folder in $oldFolders) {
            try {
                Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
            } catch { }
        }
    } catch { }
}

if (-not $env:TEMP -or -not (Test-Path $env:TEMP)) {
    throw "Variavel TEMP invalida ou inacessivel."
}

$TempRoot = Join-Path $env:TEMP ("Atlas_" + [guid]::NewGuid().ToString())
Clear-OldAtlasTempFolders -ExcludePath $TempRoot
$ZipPath = Join-Path $TempRoot "atlas.zip"
$ExtractPath = Join-Path $TempRoot "src"

try {
    Write-Host ""
    Write-Host "Atlas - Bootstrap Online"
    Write-Host "Preparando execucao temporaria..."
    Write-Host "Pasta temporaria: $TempRoot"
    Write-Host ""

    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

    Write-Host "Baixando Atlas..."
    Invoke-WebRequest -Uri $AtlasZipUrl -OutFile $ZipPath -UseBasicParsing

    if (-not (Test-Path $ZipPath)) {
        throw "Download concluido, mas o arquivo ZIP nao foi encontrado."
    }

    $zipInfo = Get-Item $ZipPath
    if ($zipInfo.Length -le 0) {
        throw "Arquivo ZIP baixado esta vazio."
    }

    Write-Host "Extraindo arquivos..."
    New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null

    if (-not (Get-Command Expand-Archive -ErrorAction SilentlyContinue)) {
        throw "Expand-Archive nao esta disponivel nesta versao do PowerShell."
    }

    Expand-Archive `
        -Path $ZipPath `
        -DestinationPath $ExtractPath `
        -Force

    $AtlasFolder = Get-ChildItem `
        -Path $ExtractPath `
        -Directory |
        Select-Object -First 1

    if (-not $AtlasFolder) {
        throw "Nao foi possivel localizar a pasta extraida do Atlas."
    }

    $AtlasEntry = Join-Path `
        $AtlasFolder.FullName `
        "bootstrap\install.ps1"

    if (-not (Test-Path $AtlasEntry)) {
        throw "Arquivo principal do Atlas nao encontrado: $AtlasEntry"
    }

    Write-Host ""
    Write-Host "Iniciando Atlas..."
    Write-Host ""

    powershell.exe `
        -ExecutionPolicy Bypass `
        -File $AtlasEntry
}
catch {
    Write-Host ""
    Write-Host "Erro durante a execucao do Atlas:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
finally {
    Write-Host ""
    Write-Host "Removendo arquivos temporarios..."

    if (Test-Path $TempRoot) {
        Remove-Item `
            -Path $TempRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    Write-Host "Finalizado."
}
