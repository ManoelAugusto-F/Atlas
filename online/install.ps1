# Atlas Online Bootstrap
# Baixa a release estavel do GitHub para TEMP, executa e remove os arquivos ao sair.

$ErrorActionPreference = "Stop"

$AtlasGithubRepo = "ManoelAugusto-F/Atlas"
$AtlasReleasesApiUrl = "https://api.github.com/repos/$AtlasGithubRepo/releases/latest"
$AtlasFallbackZipUrl = "https://github.com/ManoelAugusto-F/Atlas/archive/refs/heads/main.zip"

function Get-LatestAtlasRelease {
    try {
        $headers = @{ 'User-Agent' = 'Atlas-Bootstrap' }
        $response = Invoke-RestMethod `
            -Uri $AtlasReleasesApiUrl `
            -Method Get `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop

        if (-not $response -or -not $response.tag_name) {
            return $null
        }

        $downloadUrl = $null
        if ($response.zipball_url) {
            $downloadUrl = $response.zipball_url
        } elseif ($response.assets) {
            $asset = @($response.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1)
            if ($asset) {
                $downloadUrl = $asset.browser_download_url
            }
        }

        if (-not $downloadUrl) {
            return $null
        }

        return [PSCustomObject]@{
            Version     = $response.tag_name
            Tag         = $response.tag_name
            DownloadUrl = $downloadUrl
        }
    } catch {
        return $null
    }
}

function Download-AtlasRelease {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DownloadUrl,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        [Parameter(Mandatory = $true)]
        [string]$ExtractPath
    )

    Invoke-WebRequest -Uri $DownloadUrl -OutFile $DestinationPath -UseBasicParsing

    if (-not (Test-Path $DestinationPath)) {
        throw "Download concluido, mas o arquivo ZIP nao foi encontrado."
    }

    $zipInfo = Get-Item $DestinationPath
    if ($zipInfo.Length -le 0) {
        throw "Arquivo ZIP baixado esta vazio."
    }

    if (-not (Test-Path $ExtractPath)) {
        New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
    }

    if (-not (Get-Command Expand-Archive -ErrorAction SilentlyContinue)) {
        throw "Expand-Archive nao esta disponivel nesta versao do PowerShell."
    }

    Expand-Archive `
        -Path $DestinationPath `
        -DestinationPath $ExtractPath `
        -Force

    $atlasFolder = Get-ChildItem `
        -Path $ExtractPath `
        -Directory |
        Select-Object -First 1

    if (-not $atlasFolder) {
        throw "Nao foi possivel localizar a pasta extraida do Atlas."
    }

    $atlasEntry = Join-Path $atlasFolder.FullName "bootstrap\install.ps1"
    if (-not (Test-Path $atlasEntry)) {
        throw "Arquivo principal do Atlas nao encontrado: $atlasEntry"
    }

    return $atlasEntry
}

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

    $release = Get-LatestAtlasRelease
    $downloadUrl = $null
    $releaseVersion = "main"

    if ($release) {
        $releaseVersion = $release.Version
        Write-Host "Versao encontrada: $releaseVersion"
        Write-Host "Baixando Atlas $releaseVersion..."
        $downloadUrl = $release.DownloadUrl
    } else {
        Write-Host "Nao foi possivel consultar releases."
        Write-Host "Tentando metodo alternativo."
        Write-Host "Baixando Atlas (branch main)..."
        $downloadUrl = $AtlasFallbackZipUrl
    }

    Write-Host "Instalacao iniciada..."
    Write-Host ""

    $atlasEntry = Download-AtlasRelease `
        -DownloadUrl $downloadUrl `
        -DestinationPath $ZipPath `
        -ExtractPath $ExtractPath

    Write-Host ""
    Write-Host "Iniciando Atlas..."
    Write-Host ""

    powershell.exe `
        -ExecutionPolicy Bypass `
        -File $atlasEntry
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
