# Relatorio de Testes com Windows PowerShell 5.1

Este arquivo apresenta a matriz de testes e validacoes dos modulos de estacoes de trabalho Atlas sob o ambiente Windows PowerShell 5.1 e PowerShell Core 7.

## Matriz de Conformidade do Sistema

| Modulo | Funcao | Resultado | Observacao |
| :--- | :--- | :--- | :--- |
| **Logger** | `Write-Log` | `[OK]` | Log gravado com sucesso no diretorio `logs/`. |
| **Core** | `Wait-UserInput` | `[OK]` | Interatividade de terminal aguarda pressionamento correto de teclas. |
| **Menu** | `Show-MainMenu` | `[OK]` | Exibicao limpa e interativa no prompt nativo. |
| **Quick-Diagnostic** | `Invoke-QuickDiagnostic` | `[OK]` | Gera achados de disco, memoria, uptime e internet com sucesso. |
| **Cleanup** | `Invoke-SafeCleanup` | `[OK]` | Limpeza do cache do Windows Update, lixeira e temp do sistema. |
| **Network-Tools** | `Clear-DnsCacheSafe` | `[OK]` | Limpeza de cache DNS e renovacao DHCP realizadas com exito. |
| **OneDrive-Toolkit** | `Get-OneDriveStatus` | `[OK]` | Detecta o app em execucao (PID) e pastas de sincronizacao locais. |
| **OneDrive-Toolkit** | `Reset-OneDriveSafe` | `[OK]` | Limpa e reinicia o OneDrive por meio do argumento `/reset`. |
| **Printer-Toolkit** | `Get-PrinterList` | `[OK]` | Lista impressoras conectadas e destaca a impressora padrao. |
| **Printer-Toolkit** | `Clear-PrintQueueSafe` | `[OK]` | Limpeza fisica executada interrompendo temporariamente o Spooler. |
| **Windows-Repair** | `Invoke-SfcScannowSafe` | `[OK]` | Carregamento perfeito; executa SFC corretamente se elevado. |
| **Windows-Repair** | `Test-DismCheckHealth` | `[OK]` | Carrega no escopo e realiza verificacao passiva da saude da imagem. |
| **Windows-Repair** | `Reset-WindowsUpdateSafe` | `[OK]` | Para os servicos associados e renomeia lixeiras de distribuicao de patches. |
| **Support-Report** | `New-AtlasSupportReport` | `[OK]` | Exporta subpastas estruturadas com TXTs e o consolidador `summary.json`. |

## Observacoes sobre os Testes
* Todos os testes foram executados na plataforma Windows 11 Enterprise e sintonizados para comportamentos cross-platform no Linux Ubuntu 22.04 LTS.
* Na execucao cross-platform sob Linux, as rotinas especificas de Windows devolvem alertas de `N/A` ou de aviso de forma segura, sem interromper o loop ou lancar excecoes nao tratadas que travem a aplicacao Atlas.
