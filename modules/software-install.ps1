# ==========================================
# Atlas - Modulo Instalacao de Programas
# ==========================================

$script:SoftwareCatalogPath = $null

function script:Get-SoftwareCatalogFilePath {
    if (-not $script:SoftwareCatalogPath) {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $script:SoftwareCatalogPath = Join-Path $repoRoot "config/software-catalog.json"
    }
    return $script:SoftwareCatalogPath
}

function script:Test-IsWindowsSoftwareInstall {
    return ($IsWindows -or $env:OS -eq 'Windows_NT')
}

function script:Test-SoftwareInstallAdmin {
    if (-not (script:Test-IsWindowsSoftwareInstall)) { return $false }
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SoftwareCatalog {
    $catalogPath = script:Get-SoftwareCatalogFilePath

    if (-not (Test-Path $catalogPath)) {
        Write-Log -Message "Catalogo nao encontrado: $catalogPath" -Level "WARN"
        return $null
    }

    try {
        $raw = Get-Content -Path $catalogPath -Raw -Encoding UTF8
        $parsed = $raw | ConvertFrom-Json
        Write-AtlasSessionLog -Message "Catalogo carregado: $catalogPath" -Level "INFO"
        return $parsed
    } catch {
        Write-Log -Message "Erro ao carregar catalogo: $_" -Level "ERROR"
        Write-AtlasSessionLog -Message "Erro ao carregar catalogo: $_" -Level "ERROR"
        return $null
    }
}

function Get-SoftwareCategory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CategoryName
    )

    $catalog = Get-SoftwareCatalog
    if (-not $catalog) { return $null }

    return $catalog.categories | Where-Object { $_.name -eq $CategoryName } | Select-Object -First 1
}

function Get-SoftwareItem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CategoryName,
        [Parameter(Mandatory = $true)]
        [string]$ItemName
    )

    $category = Get-SoftwareCategory -CategoryName $CategoryName
    if (-not $category) { return $null }

    return $category.items | Where-Object { $_.name -eq $ItemName } | Select-Object -First 1
}

function Test-WingetAvailable {
    $result = [PSCustomObject]@{
        Available = $false
        Message   = "winget nao encontrado"
        Version   = "N/A"
    }

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        $result.Message = "winget disponivel apenas no Windows"
        return $result
    }

    try {
        $null = Get-Command winget -ErrorAction Stop
        $verOut = & winget --version 2>&1
        $result.Available = $true
        $result.Version = ($verOut | Select-Object -First 1).ToString().Trim()
        $result.Message = "winget disponivel: $($result.Version)"
        Write-AtlasSessionLog -Message $result.Message -Level "INFO"
    } catch {
        $result.Message = "winget nao encontrado. Instale o App Installer da Microsoft Store."
        Write-AtlasSessionLog -Message $result.Message -Level "WARN"
    }

    return $result
}

function script:Test-WingetPackageExists {
    param([string]$PackageId)

    $null = & winget show --id $PackageId --exact 2>&1
    return ($LASTEXITCODE -eq 0)
}

function Install-SoftwareByWingetSafe {
    param(
        [string]$PackageId,
        [string]$DisplayName,
        [string]$Category,
        $SoftwareItem
    )

    if ($SoftwareItem) {
        $PackageId = $SoftwareItem.id
        $DisplayName = $SoftwareItem.name
        if (-not $Category -and $SoftwareItem.PSObject.Properties['category']) {
            $Category = $SoftwareItem.category
        }
    }

    if (-not $Category) { $Category = "N/A" }

    Write-AtlasSessionLog -Message "Instalacao solicitada: $DisplayName ($PackageId)" -Level "ACTION"

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        Write-Host "Instalacao via winget disponivel apenas no Windows." -ForegroundColor Yellow
        Write-AtlasSessionLog -Message "Instalacao cancelada (nao-Windows): $PackageId" -Level "WARN"
        return $false
    }

    $wingetCheck = Test-WingetAvailable
    if (-not $wingetCheck.Available) {
        Write-Host $wingetCheck.Message -ForegroundColor Red
        Write-AtlasSessionLog -Message "winget indisponivel para $PackageId" -Level "ERROR"
        return $false
    }

    if (-not (script:Test-WingetPackageExists -PackageId $PackageId)) {
        Write-Host "Pacote nao encontrado no winget: $PackageId" -ForegroundColor Red
        Write-AtlasSessionLog -Message "Pacote nao encontrado: $PackageId" -Level "ERROR"
        return $false
    }

    Write-Host ""
    Write-Host "Programa: $DisplayName"
    Write-Host "Categoria: $Category"
    Write-Host "ID Winget: $PackageId"
    Write-Host ""
    Write-Host "Instalar agora? [S/N]: " -NoNewline
    $resp = Read-Host
    if ($resp -notmatch '^[sS]$') {
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        Write-AtlasSessionLog -Message "Instalacao cancelada pelo usuario: $PackageId" -Level "INFO"
        return $false
    }

    Write-Host ""
    Write-Host "Instalando $DisplayName..." -ForegroundColor Cyan
    Write-AtlasSessionLog -Message "Executando winget install: $PackageId" -Level "ACTION"

    try {
        $output = & winget install --id $PackageId --exact --silent --disable-interactivity `
            --accept-source-agreements --accept-package-agreements 2>&1
        $outputText = ($output | Out-String).Trim()
        if ($outputText) {
            Write-AtlasSessionLog -Message "winget output ($PackageId): $outputText" -Level "INFO"
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Instalacao concluida." -ForegroundColor Green
            Write-AtlasSessionLog -Message "Instalacao concluida: $PackageId" -Level "ACTION"
            return $true
        }

        Write-Host "Instalacao falhou. Verifique logs." -ForegroundColor Red
        Write-AtlasSessionLog -Message "Instalacao falhou (codigo $LASTEXITCODE): $PackageId" -Level "ERROR"
        Write-Log -Message "winget install falhou para $PackageId codigo $LASTEXITCODE" -Level "ERROR"
        return $false
    } catch {
        Write-Host "Instalacao falhou. Verifique logs." -ForegroundColor Red
        Write-AtlasSessionLog -Message "Erro winget install $PackageId : $_" -Level "ERROR"
        Write-Log -Message "Erro ao instalar $PackageId : $_" -Level "ERROR"
        return $false
    }
}

function Install-RsatFullSafe {
    Write-AtlasSessionLog -Message "RSAT completo solicitado" -Level "ACTION"

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        Write-Host "RSAT disponivel apenas no Windows." -ForegroundColor Yellow
        return $false
    }

    if (-not (script:Test-SoftwareInstallAdmin)) {
        Write-Host "RSAT requer PowerShell executado como Administrador." -ForegroundColor Red
        Write-AtlasSessionLog -Message "RSAT negado: sem privilegio de administrador" -Level "ERROR"
        return $false
    }

    Write-Host ""
    Write-Host "Programa: RSAT Completo"
    Write-Host "Categoria: Infraestrutura e Redes"
    Write-Host "Metodo: Add-WindowsCapability (nao usa winget)"
    Write-Host ""
    Write-Host "Instalar agora? [S/N]: " -NoNewline
    $resp = Read-Host
    if ($resp -notmatch '^[sS]$') {
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        Write-AtlasSessionLog -Message "RSAT cancelado pelo usuario" -Level "INFO"
        return $false
    }

    try {
        if (-not (Get-Command Get-WindowsCapability -ErrorAction SilentlyContinue)) {
            Write-Host "Este Windows nao suporta Get-WindowsCapability / RSAT online." -ForegroundColor Red
            Write-AtlasSessionLog -Message "RSAT nao suportado neste Windows" -Level "ERROR"
            return $false
        }

        $caps = Get-WindowsCapability -Online -ErrorAction Stop |
            Where-Object { $_.Name -like 'RSAT*' -and $_.State -eq 'NotPresent' }

        if (-not $caps -or $caps.Count -eq 0) {
            Write-Host "Nenhuma capability RSAT pendente. RSAT pode ja estar instalado." -ForegroundColor Yellow
            Write-AtlasSessionLog -Message "RSAT: nenhuma capability NotPresent" -Level "INFO"
            return $true
        }

        Write-Host ""
        Write-Host "Instalando RSAT ($($caps.Count) componentes)..." -ForegroundColor Cyan

        $ok = 0
        $fail = 0
        foreach ($cap in $caps) {
            Write-AtlasSessionLog -Message "RSAT instalando: $($cap.Name)" -Level "ACTION"
            try {
                Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop | Out-Null
                $ok++
                Write-AtlasSessionLog -Message "RSAT OK: $($cap.Name)" -Level "INFO"
            } catch {
                $fail++
                Write-AtlasSessionLog -Message "RSAT ERRO $($cap.Name): $_" -Level "ERROR"
            }
        }

        if ($fail -eq 0) {
            Write-Host "Instalacao concluida." -ForegroundColor Green
            return $true
        }

        Write-Host "Instalacao parcial. Verifique logs." -ForegroundColor Yellow
        return $false
    } catch {
        Write-Host "Instalacao falhou. Verifique logs." -ForegroundColor Red
        Write-AtlasSessionLog -Message "RSAT erro geral: $_" -Level "ERROR"
        return $false
    }
}

function Open-Microsoft365InstallPage {
    Write-AtlasSessionLog -Message "Microsoft 365: abrindo pagina oficial" -Level "ACTION"

    Write-Host ""
    Write-Host "Programa: Microsoft 365 Apps"
    Write-Host "Categoria: Microsoft"
    Write-Host ""
    Write-Host "Orientacao:" -ForegroundColor Cyan
    Write-Host "  Entre com sua conta e escolha Instalar aplicativos." -ForegroundColor Gray
    Write-Host ""

    $urls = @(
        "https://portal.office.com/account",
        "https://www.office.com"
    )

    try {
        Start-Process $urls[0]
        Write-Host "Pagina aberta no navegador." -ForegroundColor Green
        Write-AtlasSessionLog -Message "Pagina M365 aberta: $($urls[0])" -Level "INFO"
        return $true
    } catch {
        try {
            Start-Process $urls[1]
            Write-Host "Pagina aberta no navegador." -ForegroundColor Green
            Write-AtlasSessionLog -Message "Pagina M365 aberta: $($urls[1])" -Level "INFO"
            return $true
        } catch {
            Write-Host "Erro ao abrir navegador: $_" -ForegroundColor Red
            Write-AtlasSessionLog -Message "Erro ao abrir M365: $_" -Level "ERROR"
            return $false
        }
    }
}

function Update-InstalledSoftwareSafe {
    Write-AtlasSessionLog -Message "Atualizacao winget --all solicitada" -Level "ACTION"

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        Write-Host "Atualizacao via winget disponivel apenas no Windows." -ForegroundColor Yellow
        return $false
    }

    $wingetCheck = Test-WingetAvailable
    if (-not $wingetCheck.Available) {
        Write-Host $wingetCheck.Message -ForegroundColor Red
        return $false
    }

    Write-Host ""
    Write-Host "Esta opcao atualiza programas gerenciados pelo winget." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Continuar? [S/N]: " -NoNewline
    $resp = Read-Host
    if ($resp -notmatch '^[sS]$') {
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        Write-AtlasSessionLog -Message "Atualizacao winget cancelada" -Level "INFO"
        return $false
    }

    Write-Host ""
    Write-Host "Atualizando programas..." -ForegroundColor Cyan

    try {
        $output = & winget upgrade --all --silent --disable-interactivity `
            --accept-source-agreements --accept-package-agreements 2>&1
        $outputText = ($output | Out-String).Trim()
        if ($outputText) {
            Write-AtlasSessionLog -Message "winget upgrade output: $outputText" -Level "INFO"
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Atualizacao concluida." -ForegroundColor Green
            Write-AtlasSessionLog -Message "Atualizacao winget concluida" -Level "ACTION"
            return $true
        }

        Write-Host "Atualizacao falhou ou parcial. Verifique logs." -ForegroundColor Yellow
        Write-AtlasSessionLog -Message "winget upgrade codigo $LASTEXITCODE" -Level "WARN"
        return $false
    } catch {
        Write-Host "Atualizacao falhou. Verifique logs." -ForegroundColor Red
        Write-AtlasSessionLog -Message "Erro winget upgrade: $_" -Level "ERROR"
        return $false
    }
}

function Export-SoftwareInventory {
    Write-AtlasSessionLog -Message "Inventario de software solicitado" -Level "ACTION"

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        Write-Host "Inventario via winget disponivel apenas no Windows." -ForegroundColor Yellow
        return $null
    }

    $wingetCheck = Test-WingetAvailable
    if (-not $wingetCheck.Available) {
        Write-Host $wingetCheck.Message -ForegroundColor Red
        return $null
    }

    $repoRoot = Split-Path $PSScriptRoot -Parent
    $reportsDir = Join-Path $repoRoot "reports"
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outFile = Join-Path $reportsDir "software_inventory_$timestamp.txt"

    Write-Host ""
    Write-Host "Gerando inventario..." -ForegroundColor Cyan

    try {
        $header = @(
            "Atlas - Inventario de Software (winget list)"
            "Gerado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            "Host: $([System.Environment]::MachineName)"
            "=========================================="
            ""
        )
        $listOut = & winget list 2>&1
        $body = ($listOut | Out-String)
        Set-Content -Path $outFile -Value (($header -join "`n") + $body) -Encoding UTF8

        Write-Host "Inventario salvo em:" -ForegroundColor Green
        Write-Host "  $outFile" -ForegroundColor Cyan
        Write-AtlasSessionLog -Message "Inventario exportado: $outFile" -Level "ACTION"
        return $outFile
    } catch {
        Write-Host "Falha ao exportar inventario. Verifique logs." -ForegroundColor Red
        Write-AtlasSessionLog -Message "Erro inventario: $_" -Level "ERROR"
        return $null
    }
}

function script:Invoke-SoftwareCatalogItem {
    param(
        $Item,
        [string]$CategoryName
    )

    Write-AtlasSessionLog -Message "Item selecionado: $($Item.name) [$CategoryName]" -Level "ACTION"

    if ($Item.id -eq "SPECIAL:RSAT_FULL") {
        [void](Install-RsatFullSafe)
        return
    }

    if ($Item.id -eq "SPECIAL:MICROSOFT_365") {
        [void](Open-Microsoft365InstallPage)
        return
    }

    [void](Install-SoftwareByWingetSafe -SoftwareItem $Item -Category $CategoryName)
}

function Show-SoftwareCategoryMenu {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CategoryName
    )

    $category = Get-SoftwareCategory -CategoryName $CategoryName
    if (-not $category) {
        Write-Host "Categoria nao encontrada: $CategoryName" -ForegroundColor Red
        Wait-UserInput
        return
    }

    $items = @($category.items)
    if ($items.Count -eq 0) {
        Write-Host "Nenhum programa nesta categoria." -ForegroundColor Yellow
        Wait-UserInput
        return
    }

    $running = $true
    while ($running) {
        Clear-Host
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  Atlas - $CategoryName" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""

        for ($i = 0; $i -lt $items.Count; $i++) {
            $num = $i + 1
            Write-Host "[$num]  $($items[$i].name)"
        }
        Write-Host "[0]  Voltar"
        Write-Host ""

        Write-AtlasSessionLog -Message "Submenu categoria: $CategoryName" -Level "MENU"
        $opt = Read-Host "Escolha uma opcao"

        if ($opt -eq "0") {
            $running = $false
            continue
        }

        $idx = 0
        if ([int]::TryParse($opt, [ref]$idx) -and $idx -ge 1 -and $idx -le $items.Count) {
            script:Invoke-SoftwareCatalogItem -Item $items[$idx - 1] -CategoryName $CategoryName
            Wait-UserInput
        } else {
            Write-Host "Opcao invalida." -ForegroundColor Yellow
            Wait-UserInput
        }
    }
}

function script:Get-SoftwareCategoryMenuMap {
    $catalog = Get-SoftwareCatalog
    if (-not $catalog) { return @{} }

    $map = @{}
    $index = 1
    foreach ($cat in $catalog.categories) {
        $map[[string]$index] = $cat.name
        $index++
    }
    return $map
}

function Show-SoftwareInstallMenu {
    $running = $true

    while ($running) {
        Clear-Host
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  Atlas - Instalacao de Programas" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[1]  Navegadores"
        Write-Host "[2]  PDF e Documentos"
        Write-Host "[3]  Desenvolvimento"
        Write-Host "[4]  Infraestrutura e Redes"
        Write-Host "[5]  Banco de Dados"
        Write-Host "[6]  Microsoft"
        Write-Host "[7]  Utilitarios"
        Write-Host "[8]  Atualizar programas instalados"
        Write-Host "[9]  Inventario de software"
        Write-Host "[0]  Voltar"
        Write-Host ""

        Write-AtlasSessionLog -Message "Menu Instalacao de Programas exibido" -Level "MENU"
        $opt = Read-Host "Escolha uma opcao"
        Write-AtlasSessionLog -Message "Instalacao de Programas opcao: $opt" -Level "MENU"

        $categoryMap = script:Get-SoftwareCategoryMenuMap

        switch ($opt) {
            { $_ -in $categoryMap.Keys } {
                Show-SoftwareCategoryMenu -CategoryName $categoryMap[$_]
            }
            "8" {
                [void](Update-InstalledSoftwareSafe)
                Wait-UserInput
            }
            "9" {
                [void](Export-SoftwareInventory)
                Wait-UserInput
            }
            "0" {
                Write-AtlasSessionLog -Message "Saindo do menu Instalacao de Programas" -Level "MENU"
                $running = $false
            }
            default {
                Write-Host "Opcao invalida." -ForegroundColor Yellow
                Wait-UserInput
            }
        }
    }
}
