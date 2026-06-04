# ==========================================
# Atlas - Modulo Instalacao de Programas
# ==========================================

function script:Test-IsWindowsSoftwareInstall {
    return ($IsWindows -or $env:OS -eq 'Windows_NT')
}

function script:Confirm-SoftwareInstallAction {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $resp = Read-Host "Digite S para confirmar"
    return ($resp -match '^[sS]$')
}

function Test-WingetAvailable {
    Write-Log -Message "Verificando disponibilidade do winget" -Level "INFO"

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
        $wingetCmd = Get-Command winget -ErrorAction Stop
        $verOut = & winget --version 2>&1
        $result.Available = $true
        $result.Version = ($verOut | Select-Object -First 1).ToString().Trim()
        $result.Message = "winget disponivel: $($result.Version)"
        Write-Log -Message $result.Message -Level "INFO"
    } catch {
        $result.Message = "winget nao encontrado. Instale o App Installer da Microsoft Store."
        Write-Log -Message $result.Message -Level "WARN"
    }

    return $result
}

function Install-SoftwareByWingetSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [string]$Category
    )

    Write-Log -Message "Solicitacao de instalacao: $DisplayName ($PackageId)" -Level "INFO"

    if (-not (script:Test-IsWindowsSoftwareInstall)) {
        Write-Host ""
        Write-Host "Instalacao via winget disponivel apenas no Windows." -ForegroundColor Yellow
        return $false
    }

    $wingetCheck = Test-WingetAvailable
    if (-not $wingetCheck.Available) {
        Write-Host ""
        Write-Host $wingetCheck.Message -ForegroundColor Red
        return $false
    }

    Write-Host ""
    Write-Host "Pacote selecionado:" -ForegroundColor Cyan
    Write-Host "  Nome      : $DisplayName"
    Write-Host "  Categoria : $Category"
    Write-Host "  ID winget : $PackageId"
    Write-Host ""
    Write-Host "Comando: winget install --id $PackageId --accept-source-agreements --accept-package-agreements" -ForegroundColor Gray

    if (-not (script:Confirm-SoftwareInstallAction "Confirma a instalacao deste pacote?")) {
        Write-Log -Message "Instalacao cancelada: $PackageId" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return $false
    }

    try {
        Write-Host ""
        Write-Host "Instalando $DisplayName..." -ForegroundColor Cyan
        & winget install --id $PackageId --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message "Instalacao concluida: $PackageId" -Level "INFO"
            Write-Host "Instalacao concluida com sucesso." -ForegroundColor Green
            return $true
        }
        Write-Log -Message "winget retornou codigo $LASTEXITCODE para $PackageId" -Level "WARN"
        Write-Host "Instalacao finalizada com codigo de saida: $LASTEXITCODE" -ForegroundColor Yellow
        return $false
    } catch {
        Write-Log -Message "Erro ao instalar $PackageId : $_" -Level "ERROR"
        Write-Host "Erro ao instalar pacote: $_" -ForegroundColor Red
        return $false
    }
}

function script:Get-AtlasSoftwareCatalog {
    return @{
        Browsers = @(
            @{ Name = "Google Chrome"; Id = "Google.Chrome" },
            @{ Name = "Mozilla Firefox"; Id = "Mozilla.Firefox" },
            @{ Name = "Brave"; Id = "Brave.Brave" }
        )
        Dev = @(
            @{ Name = "Visual Studio Code"; Id = "Microsoft.VisualStudioCode" },
            @{ Name = "Git"; Id = "Git.Git" },
            @{ Name = "Python 3"; Id = "Python.Python.3" },
            @{ Name = "Windows Terminal"; Id = "Microsoft.WindowsTerminal" }
        )
        Pdf = @(
            @{ Name = "PDF24 Creator"; Id = "geeksoftwareGmbH.PDF24Creator" },
            @{ Name = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit" },
            @{ Name = "LibreOffice"; Id = "TheDocumentFoundation.LibreOffice" },
            @{ Name = "Bizagi Modeler"; Id = "Bizagi.Modeler" }
        )
        Utilities = @(
            @{ Name = "7-Zip"; Id = "7zip.7zip" },
            @{ Name = "Notepad++"; Id = "Notepad++.Notepad++" },
            @{ Name = "PowerToys"; Id = "Microsoft.PowerToys" },
            @{ Name = "Everything"; Id = "voidtools.Everything" }
        )
    }
}

function script:Show-SoftwarePackageMenu {
    param(
        [string]$Title,
        [string]$Category,
        [array]$Packages
    )

    $running = $true
    while ($running) {
        Clear-Host
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""

        for ($i = 0; $i -lt $Packages.Count; $i++) {
            $num = $i + 1
            Write-Host "[$num]  $($Packages[$i].Name)"
        }
        Write-Host "[0]  Voltar"
        Write-Host ""

        $opt = Read-Host "Escolha uma opcao"
        if ($opt -eq "0") {
            $running = $false
            continue
        }

        $idx = 0
        if ([int]::TryParse($opt, [ref]$idx) -and $idx -ge 1 -and $idx -le $Packages.Count) {
            $pkg = $Packages[$idx - 1]
            Install-SoftwareByWingetSafe -PackageId $pkg.Id -DisplayName $pkg.Name -Category $Category
            Wait-UserInput
        } else {
            Write-Host "Opcao invalida." -ForegroundColor Yellow
            Wait-UserInput
        }
    }
}

function Show-BrowserInstallMenu {
    $catalog = script:Get-AtlasSoftwareCatalog
    script:Show-SoftwarePackageMenu -Title "Atlas - Navegadores (Instalacao)" -Category "Navegadores" -Packages $catalog.Browsers
}

function Show-DevInstallMenu {
    $catalog = script:Get-AtlasSoftwareCatalog
    script:Show-SoftwarePackageMenu -Title "Atlas - Desenvolvimento (Instalacao)" -Category "Desenvolvimento" -Packages $catalog.Dev
}

function Show-PdfInstallMenu {
    $catalog = script:Get-AtlasSoftwareCatalog
    script:Show-SoftwarePackageMenu -Title "Atlas - PDF e Documentos (Instalacao)" -Category "PDF e documentos" -Packages $catalog.Pdf
}

function Show-UtilitiesInstallMenu {
    $catalog = script:Get-AtlasSoftwareCatalog
    script:Show-SoftwarePackageMenu -Title "Atlas - Utilitarios (Instalacao)" -Category "Utilitarios" -Packages $catalog.Utilities
}

function Install-RecommendedPackageSafe {
    Write-Log -Message "Pacote recomendado solicitado" -Level "INFO"

    $recommended = @(
        @{ Name = "Google Chrome"; Id = "Google.Chrome"; Category = "Navegadores" },
        @{ Name = "7-Zip"; Id = "7zip.7zip"; Category = "Utilitarios" },
        @{ Name = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit"; Category = "PDF e documentos" },
        @{ Name = "PDF24 Creator"; Id = "geeksoftwareGmbH.PDF24Creator"; Category = "PDF e documentos" }
    )

    Write-Host ""
    Write-Host "Pacote recomendado - os seguintes programas serao instalados:" -ForegroundColor Cyan
    foreach ($pkg in $recommended) {
        Write-Host "  - $($pkg.Name) [$($pkg.Category)] -> $($pkg.Id)"
    }
    Write-Host ""

    if (-not (script:Confirm-SoftwareInstallAction "Confirma instalacao do pacote recomendado?")) {
        Write-Log -Message "Pacote recomendado cancelado" -Level "INFO"
        Write-Host "Operacao cancelada." -ForegroundColor Gray
        return
    }

    foreach ($pkg in $recommended) {
        Write-Host ""
        Write-Host "--- $($pkg.Name) ---" -ForegroundColor Cyan
        if (-not (script:Confirm-SoftwareInstallAction "Instalar $($pkg.Name) agora?")) {
            Write-Host "Pulando $($pkg.Name)." -ForegroundColor Gray
            continue
        }
        Install-SoftwareByWingetSafe -PackageId $pkg.Id -DisplayName $pkg.Name -Category $pkg.Category
    }
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
        Write-Host "[1]  Verificar Winget"
        Write-Host "[2]  Navegadores"
        Write-Host "[3]  Desenvolvimento"
        Write-Host "[4]  PDF e documentos"
        Write-Host "[5]  Utilitarios"
        Write-Host "[6]  Instalar pacote recomendado"
        Write-Host "[0]  Voltar"
        Write-Host ""

        $opt = Read-Host "Escolha uma opcao"

        switch ($opt) {
            "1" {
                $check = Test-WingetAvailable
                Write-Host ""
                Write-Host $check.Message -ForegroundColor $(if ($check.Available) { "Green" } else { "Yellow" })
                Wait-UserInput
            }
            "2" { Show-BrowserInstallMenu }
            "3" { Show-DevInstallMenu }
            "4" { Show-PdfInstallMenu }
            "5" { Show-UtilitiesInstallMenu }
            "6" { Install-RecommendedPackageSafe; Wait-UserInput }
            "0" {
                Write-Log -Message "Saindo do menu Instalacao de Programas" -Level "INFO"
                $running = $false
            }
            default {
                Write-Host "Opcao invalida." -ForegroundColor Yellow
                Wait-UserInput
            }
        }
    }
}
