function Get-DefenderStatus {

    Write-Host ""
    Write-Host "Status do Microsoft Defender:" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-IsWindows)) {
        Write-Host "Esta funcao e exclusiva do Windows." -ForegroundColor DarkGray
        Write-Log -Message "Get-DefenderStatus chamado no Linux (sem acao)" -Level "INFO"
        return
    }

    try {
        $status = Get-MpComputerStatus -ErrorAction Stop

        $enabled   = if ($status.AntivirusEnabled)        { "Ativado" }  else { "DESATIVADO" }
        $rtEnabled = if ($status.RealTimeProtectionEnabled) { "Ativado" } else { "DESATIVADO" }
        $upToDate  = if ($status.AntivirusSignatureAge -le 3) { "Atualizada" } else { "DESATUALIZADA ($($status.AntivirusSignatureAge) dias)" }

        Write-Host ("  Antivirus            : {0}" -f $enabled)   -ForegroundColor (if ($status.AntivirusEnabled)          { "Green" } else { "Red" })
        Write-Host ("  Protecao em tempo real: {0}" -f $rtEnabled) -ForegroundColor (if ($status.RealTimeProtectionEnabled) { "Green" } else { "Red" })
        Write-Host ("  Assinatura           : {0}" -f $upToDate)   -ForegroundColor (if ($status.AntivirusSignatureAge -le 3) { "Green" } else { "Yellow" })
        Write-Host ("  Ultima verificacao   : {0}" -f $status.QuickScanAge)

        Write-Log -Message "Get-DefenderStatus executado. Antivirus: $enabled" -Level "INFO"
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        Write-Host "Modulo do Microsoft Defender nao encontrado neste sistema." -ForegroundColor DarkGray
        Write-Log -Message "Get-DefenderStatus: modulo Defender indisponivel" -Level "WARN"
    }
    catch {
        Write-Host "Erro ao obter status do Defender: $_" -ForegroundColor Red
        Write-Log -Message "Erro em Get-DefenderStatus: $_" -Level "ERROR"
    }
}
