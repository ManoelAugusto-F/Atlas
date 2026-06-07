# ==========================================
# Atlas - Modulo Instalacao de Programas
# ==========================================

$script:SoftwareCatalogPath = $null
$script:Microsoft365WingetId = "Microsoft.Office"

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

function script:Test-IsSpecialCatalogId {
    param([string]$PackageId)
    return ($PackageId -like "SPECIAL:*")
}

function script:Test-WingetPackageExists {
    param([string]$PackageId)

    if (script:Test-IsSpecialCatalogId -PackageId $PackageId) {
        return $true
    }

    & winget show --id $PackageId --exact
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

    if (-not (script:Test-WingetPackageExists -PackageId $PackageId)) {
        Write-Host ""
        Write-Host "Pacote nao encontrado no winget. Execute o teste de catalogo." -ForegroundColor Red
        Write-AtlasSessionLog -Message "Pacote nao encontrado: $PackageId" -Level "ERROR"
        return $false
    }

    Write-Host ""
    Write-Host "Instalando $DisplayName..." -ForegroundColor Cyan
    Write-AtlasSessionLog -Message "Executando winget install: $PackageId" -Level "ACTION"

    try {
        & winget install --id $PackageId --exact `
            --accept-source-agreements --accept-package-agreements
        $exitCode = $LASTEXITCODE
        Write-AtlasSessionLog -Message "winget install finalizado ($PackageId) codigo $exitCode" -Level "INFO"

        if ($exitCode -eq 0) {
            Write-Host ""
            Write-Host "Instalacao concluida." -ForegroundColor Green
            Write-AtlasSessionLog -Message "Instalacao concluida: $PackageId" -Level "ACTION"
            Write-AtlasLog -Nivel INFO -Modulo "Instalacao" -Acao $DisplayName -Resultado "Sucesso"
            return $true
        }

        Write-Host ""
        Write-Host "Instalacao falhou. Verifique logs." -ForegroundColor Red
        Write-AtlasSessionLog -Message "Instalacao falhou (codigo $exitCode): $PackageId" -Level "ERROR"
        Write-Log -Message "winget install falhou para $PackageId codigo $exitCode" -Level "ERROR"
        Write-AtlasLog -Nivel ERROR -Modulo "Instalacao" -Acao $DisplayName -Resultado "Falha"
        return $false
    } catch {
        Write-Host ""
        Write-Host "Instalacao falhou. Verifique logs." -ForegroundColor Red
        Write-AtlasSessionLog -Message "Erro winget install $PackageId : $_" -Level "ERROR"
        Write-Log -Message "Erro ao instalar $PackageId : $_" -Level "ERROR"
        Write-AtlasLog -Nivel ERROR -Modulo "Instalacao" -Acao $DisplayName -Resultado "Falha"
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

function Test-Microsoft365WingetAvailable {
    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        return $false
    }

    $wingetCheck = Test-WingetAvailable
    if (-not $wingetCheck.Available) {
        return $false
    }

    & winget show --id $script:Microsoft365WingetId --exact
    return ($LASTEXITCODE -eq 0)
}

function Test-Microsoft365Installed {
    Write-AtlasSessionLog -Message "Verificando Microsoft 365 instalado" -Level "ACTION"

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        Write-Host "Verificacao disponivel apenas no Windows." -ForegroundColor Yellow
        return $false
    }

    $installed = $false
    $detail = "Nao detectado"

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\winword.exe",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe"
    )

    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            $installed = $true
            try {
                $val = Get-ItemProperty -Path $regPath -Name "(Default)" -ErrorAction Stop
                $detail = $val."(Default)"
            } catch {
                $detail = "Registro encontrado"
            }
            break
        }
    }

    if (-not $installed) {
        $officePaths = @(
            "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE",
            "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\WINWORD.EXE"
        )
        foreach ($p in $officePaths) {
            if (Test-Path $p) {
                $installed = $true
                $detail = $p
                break
            }
        }
    }

    Write-Host ""
    if ($installed) {
        Write-Host "Microsoft 365 / Office: INSTALADO" -ForegroundColor Green
        Write-Host "  Caminho: $detail" -ForegroundColor Gray
        Write-AtlasSessionLog -Message "M365 instalado: $detail" -Level "INFO"
    } else {
        Write-Host "Microsoft 365 / Office: NAO INSTALADO" -ForegroundColor Yellow
        Write-AtlasSessionLog -Message "M365 nao instalado" -Level "INFO"
    }

    return $installed
}

function Install-Microsoft365AppsSafe {
    Write-AtlasSessionLog -Message "Instalacao Microsoft 365 Apps solicitada" -Level "ACTION"

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        Write-Host "Instalacao disponivel apenas no Windows." -ForegroundColor Yellow
        return $false
    }

    if (Test-Microsoft365WingetAvailable) {
        Write-Host ""
        Write-Host "Microsoft 365 Apps sera instalado via winget." -ForegroundColor Cyan
        Write-Host "ID Winget: $($script:Microsoft365WingetId)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "A conta corporativa ou escolar sera adicionada depois," -ForegroundColor Yellow
        Write-Host "ao abrir Word, Excel, Outlook ou outro aplicativo Office." -ForegroundColor Yellow
        Write-Host ""

        [void](Install-SoftwareByWingetSafe `
            -PackageId $script:Microsoft365WingetId `
            -DisplayName "Microsoft 365 Apps" `
            -Category "Microsoft")
        return $true
    }

    Write-Host ""
    Write-Host "A instalacao automatizada pelo winget nao foi confirmada neste ambiente." -ForegroundColor Yellow
    Write-Host "Use o portal oficial como fallback." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Abrir portal Microsoft 365 agora? [S/N]: " -NoNewline
    $resp = Read-Host
    if ($resp -match '^[sS]$') {
        [void](Open-Microsoft365InstallPage)
    } else {
        Write-Host "Operacao cancelada." -ForegroundColor Gray
    }
    return $false
}

function Repair-Microsoft365Safe {
    Write-AtlasSessionLog -Message "Reparo Microsoft 365 solicitado" -Level "ACTION"

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        Write-Host "Reparo disponivel apenas no Windows." -ForegroundColor Yellow
        return $false
    }

    if (-not (Test-Microsoft365Installed)) {
        Write-Host ""
        Write-Host "Microsoft 365 nao parece instalado. Instale antes de reparar." -ForegroundColor Yellow
        return $false
    }

    Write-Host ""
    Write-Host "Reparar Microsoft 365 Apps?" -ForegroundColor Yellow
    Write-Host "Isso pode levar alguns minutos." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Continuar? [S/N]: " -NoNewline
    $resp = Read-Host
    if ($resp -notmatch '^[sS]$') {
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return $false
    }

    $c2rPaths = @(
        "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe",
        "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    )

    $c2r = $c2rPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($c2r) {
        Write-Host ""
        Write-Host "Executando reparo online do Office..." -ForegroundColor Cyan
        Write-AtlasSessionLog -Message "OfficeClickToRun repair: $c2r" -Level "ACTION"
        try {
            Start-Process -FilePath $c2r -ArgumentList "/repair", "displaylevel=False" -Wait
            Write-Host "Reparo concluido. Reinicie os aplicativos Office se necessario." -ForegroundColor Green
            Write-AtlasSessionLog -Message "Reparo M365 concluido" -Level "INFO"
            return $true
        } catch {
            Write-Host "Erro ao executar reparo: $_" -ForegroundColor Red
            Write-AtlasSessionLog -Message "Erro reparo M365: $_" -Level "ERROR"
        }
    }

    Write-Host ""
    Write-Host "OfficeClickToRun nao encontrado. Abrindo Programas e Recursos..." -ForegroundColor Yellow
    Write-Host "Procure Microsoft 365 ou Office e clique em Alterar > Reparar Online." -ForegroundColor Gray
    try {
        Start-Process "appwiz.cpl"
        return $true
    } catch {
        Write-Host "Erro ao abrir painel: $_" -ForegroundColor Red
        return $false
    }
}

function Open-Microsoft365InstallPage {
    Write-AtlasSessionLog -Message "Microsoft 365: abrindo portal oficial" -Level "ACTION"

    $portalUrl = "https://portal.office.com/account"

    Write-Host ""
    Write-Host "Portal Microsoft 365" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Orientacao:" -ForegroundColor Cyan
    Write-Host "  Entre com sua conta corporativa ou escolar." -ForegroundColor Gray
    Write-Host "  Depois clique em Instalar aplicativos." -ForegroundColor Gray
    Write-Host "  Use esta opcao quando o Office depende de licenciamento Microsoft 365." -ForegroundColor Gray
    Write-Host ""

    try {
        Start-Process $portalUrl
        Write-Host "Pagina aberta: $portalUrl" -ForegroundColor Green
        Write-AtlasSessionLog -Message "Portal M365 aberto: $portalUrl" -Level "INFO"
        return $true
    } catch {
        Write-Host "Erro ao abrir navegador: $_" -ForegroundColor Red
        Write-AtlasSessionLog -Message "Erro ao abrir portal M365: $_" -Level "ERROR"
        return $false
    }
}

function Show-Microsoft365Menu {
    $running = $true

    while ($running) {
        Clear-Host
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  Atlas - Microsoft 365" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[1]  Instalar Microsoft 365 Apps"
        Write-Host "[2]  Reparar Microsoft 365"
        Write-Host "[3]  Verificar Microsoft 365 instalado"
        Write-Host "[4]  Abrir Portal Microsoft 365"
        Write-Host "[0]  Voltar"
        Write-Host ""

        Write-AtlasSessionLog -Message "Submenu Microsoft 365 exibido" -Level "MENU"
        $opt = Read-Host "Escolha uma opcao"

        switch ($opt) {
            "1" { [void](Install-Microsoft365AppsSafe); Wait-UserInput }
            "2" { [void](Repair-Microsoft365Safe); Wait-UserInput }
            "3" { [void](Test-Microsoft365Installed); Wait-UserInput }
            "4" { [void](Open-Microsoft365InstallPage); Wait-UserInput }
            "0" {
                Write-AtlasSessionLog -Message "Saindo submenu Microsoft 365" -Level "MENU"
                $running = $false
            }
            default {
                Write-Host "Opcao invalida." -ForegroundColor Yellow
                Wait-UserInput
            }
        }
    }
}

function Get-WingetAvailableUpgrades {
    Write-AtlasSessionLog -Message "Consulta winget upgrade (previa)" -Level "ACTION"

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        Write-Host "Atualizacao via winget disponivel apenas no Windows." -ForegroundColor Yellow
        return $null
    }

    $wingetCheck = Test-WingetAvailable
    if (-not $wingetCheck.Available) {
        Write-Host $wingetCheck.Message -ForegroundColor Red
        return $null
    }

    Write-Host ""
    Write-Host "Verificando atualizacoes disponiveis..." -ForegroundColor Cyan
    Write-Host ""

    try {
        & winget upgrade
        $exitCode = $LASTEXITCODE
        Write-AtlasSessionLog -Message "winget upgrade (previa) codigo $exitCode" -Level "INFO"
        return [PSCustomObject]@{
            ExitCode = $exitCode
        }
    } catch {
        Write-Host "Falha ao verificar atualizacoes. Verifique logs." -ForegroundColor Red
        Write-AtlasSessionLog -Message "Erro winget upgrade previa: $_" -Level "ERROR"
        return $null
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

    $preview = Get-WingetAvailableUpgrades
    if (-not $preview) {
        return $false
    }

    Write-Host ""
    Write-Host "Deseja atualizar todos os programas listados? [S/N]: " -NoNewline
    $resp = Read-Host
    if ($resp -notmatch '^[sS]$') {
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        Write-AtlasSessionLog -Message "Atualizacao winget cancelada pelo usuario" -Level "INFO"
        return $false
    }

    Write-Host ""
    Write-Host "Atualizando programas..." -ForegroundColor Cyan
    Write-AtlasSessionLog -Message "Executando winget upgrade --all" -Level "ACTION"

    try {
        & winget upgrade --all --accept-source-agreements --accept-package-agreements
        $exitCode = $LASTEXITCODE
        Write-AtlasSessionLog -Message "winget upgrade --all finalizado codigo $exitCode" -Level "INFO"

        Write-Host ""
        if ($exitCode -eq 0) {
            Write-Host "Atualizacao concluida." -ForegroundColor Green
            Write-AtlasSessionLog -Message "Atualizacao winget concluida" -Level "ACTION"
            return $true
        }

        Write-Host "Atualizacao falhou ou parcial. Verifique logs." -ForegroundColor Yellow
        Write-AtlasSessionLog -Message "winget upgrade --all codigo $exitCode" -Level "WARN"
        return $false
    } catch {
        Write-Host ""
        Write-Host "Atualizacao falhou. Verifique logs." -ForegroundColor Red
        Write-AtlasSessionLog -Message "Erro winget upgrade --all: $_" -Level "ERROR"
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

function script:Get-WingetCatalogEntries {
    $catalog = Get-SoftwareCatalog
    if (-not $catalog) { return @() }

    $entries = @()
    foreach ($cat in $catalog.categories) {
        foreach ($item in $cat.items) {
            if ($item.manager -eq "winget" -and -not (script:Test-IsSpecialCatalogId -PackageId $item.id)) {
                $entries += [PSCustomObject]@{
                    Name = $item.name
                    Category = $cat.name
                    Id = $item.id
                }
            }
        }
    }
    return $entries
}

function Test-WingetCatalogItem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        [string]$DisplayName = $PackageId
    )

    if (script:Test-IsSpecialCatalogId -PackageId $PackageId) {
        return [PSCustomObject]@{
            Name = $DisplayName
            Id = $PackageId
            Status = "SKIP"
            Ok = $true
        }
    }

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        return [PSCustomObject]@{
            Name = $DisplayName
            Id = $PackageId
            Status = "SKIP"
            Ok = $true
        }
    }

    $wingetCheck = Test-WingetAvailable
    if (-not $wingetCheck.Available) {
        return [PSCustomObject]@{
            Name = $DisplayName
            Id = $PackageId
            Status = "SKIP"
            Ok = $true
        }
    }

    & winget show --id $PackageId --exact
    $ok = ($LASTEXITCODE -eq 0)

    return [PSCustomObject]@{
        Name = $DisplayName
        Id = $PackageId
        Status = $(if ($ok) { "OK" } else { "ERRO" })
        Ok = $ok
    }
}

function Export-WingetCatalogValidationHtml {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results,
        [string]$OutputPath
    )

    $total = $Results.Count
    $okCount = @($Results | Where-Object { $_.Status -eq "OK" }).Count
    $errCount = @($Results | Where-Object { $_.Status -eq "ERRO" }).Count
    $skipCount = @($Results | Where-Object { $_.Status -eq "SKIP" }).Count

    $rows = ""
    foreach ($r in $Results) {
        $statusClass = switch ($r.Status) {
            "OK" { "ok" }
            "ERRO" { "erro" }
            default { "skip" }
        }
        $cat = if ($r.Category) { $r.Category } else { "N/A" }
        $safeName = ($r.Name -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
        $safeCat = ($cat -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
        $safeId = ($r.Id -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
        $rows += "<tr class=""$statusClass""><td>$safeName</td><td>$safeCat</td><td>$safeId</td><td>$($r.Status)</td></tr>`n"
    }

    $generated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $html = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Atlas - Validacao Catalogo Winget</title>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; background: #f5f6f8; color: #222; }
        .wrap { max-width: 960px; margin: 0 auto; background: #fff; padding: 24px; border-radius: 8px; }
        h1 { color: #364fc7; }
        .summary { display: flex; gap: 16px; margin: 20px 0; }
        .card { flex: 1; padding: 14px; border-radius: 6px; background: #f1f3f5; }
        table { width: 100%; border-collapse: collapse; font-size: 14px; }
        th, td { padding: 10px; border-bottom: 1px solid #e9ecef; text-align: left; }
        th { background: #f8f9fa; }
        tr.ok td:last-child { color: #2b8a3e; font-weight: bold; }
        tr.erro td:last-child { color: #c92a2a; font-weight: bold; }
        tr.skip td:last-child { color: #868e96; }
    </style>
</head>
<body>
<div class="wrap">
    <h1>Atlas - Validacao do Catalogo Winget</h1>
    <p>Gerado em: $generated</p>
    <div class="summary">
        <div class="card"><strong>Total</strong><br/>$total</div>
        <div class="card"><strong>OK</strong><br/>$okCount</div>
        <div class="card"><strong>Erro</strong><br/>$errCount</div>
        <div class="card"><strong>Ignorados</strong><br/>$skipCount</div>
    </div>
    <table>
        <thead><tr><th>Nome</th><th>Categoria</th><th>ID Winget</th><th>Status</th></tr></thead>
        <tbody>
        $rows
        </tbody>
    </table>
</div>
</body>
</html>
"@

    if (-not $OutputPath) {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $reportsDir = Join-Path $repoRoot "reports"
        if (-not (Test-Path $reportsDir)) {
            New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
        }
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputPath = Join-Path $reportsDir "winget_catalog_validation_$ts.html"
    }

    Set-Content -Path $OutputPath -Value $html -Encoding UTF8
    return $OutputPath
}

function Invoke-WingetCatalogValidation {
    $entries = script:Get-WingetCatalogEntries
    $results = @()

    foreach ($entry in $entries) {
        $test = Test-WingetCatalogItem -PackageId $entry.Id -DisplayName $entry.Name
        $results += [PSCustomObject]@{
            Name = $entry.Name
            Category = $entry.Category
            Id = $entry.Id
            Status = $test.Status
            Ok = $test.Ok
        }
    }

    $reportPath = Export-WingetCatalogValidationHtml -Results $results
    $hasErrors = @($results | Where-Object { $_.Status -eq "ERRO" }).Count -gt 0

    return [PSCustomObject]@{
        Results = $results
        ReportPath = $reportPath
        HasErrors = $hasErrors
        Total = $results.Count
        OkCount = @($results | Where-Object { $_.Status -eq "OK" }).Count
        ErrorCount = @($results | Where-Object { $_.Status -eq "ERRO" }).Count
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

    if ($Item.id -eq "SPECIAL:MICROSOFT_365" -or $Item.id -eq $script:Microsoft365WingetId) {
        Show-Microsoft365Menu
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
