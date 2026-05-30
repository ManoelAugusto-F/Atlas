# Atlas — Arquitetura do Projeto

## Visão Geral

Atlas é um toolkit de suporte e manutenção Windows, desenvolvido em **PowerShell 7.x** com design modular. Compatível com PowerShell Core no Linux para desenvolvimento e validação. Funções exclusivas do Windows exibem mensagem informativa quando executadas no Linux sem lançar exceções.

---

## Estrutura de Diretórios

```
Atlas/
├── bootstrap/
│   └── install.ps1              # Ponto de entrada principal
├── config/
│   └── apps.json                # Catálogo de aplicativos (winget)
├── docs/
│   └── ARCHITECTURE.md          # Este documento
├── logs/
│   └── provisionador.log        # Log de execução (criado em runtime)
├── modules/
│   ├── logger.ps1               # Sistema de log centralizado
│   ├── menu.ps1                 # Menu interativo
│   ├── system.ps1               # Utilitários e informações do sistema
│   ├── network.ps1              # Diagnósticos de rede
│   ├── maintenance.ps1          # Manutenção (limpeza, serviços)
│   ├── disk.ps1                 # Disco e tempo de boot
│   ├── triage.ps1               # Triagem rápida da máquina
│   ├── corporate-network.ps1    # Saúde de rede corporativa
│   ├── windows-health.ps1       # Saúde específica do Windows
│   └── evidence.ps1             # Coleta de evidências para atendimento
├── reports/                     # Bundles de evidências gerados em runtime
├── tests/
│   └── test_loop.ps1            # Teste automatizado de todas as opções
└── VERSION.md                   # Versão e histórico do projeto
```

---

## Módulos

### logger.ps1

**Função exportada:** `Write-Log`

Sistema de log unificado. Escreve no terminal com cor por nível e persiste em `logs/provisionador.log`.

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `-Message` | string | Texto da mensagem |
| `-Level` | string | `INFO` (Cyan) \| `WARN` (Yellow) \| `ERROR` (Red) — padrão: INFO |

---

### menu.ps1

**Função exportada:** `Show-MainMenu`

Limpa o terminal e exibe o menu com as 14 opções disponíveis mais saída (0). Não possui dependências além do terminal.

---

### system.ps1

**Funções exportadas:** `Test-IsWindows`, `Test-IsLinux`, `Wait-UserInput`, `Get-SystemEnvironment`, `Get-SystemInformation`, `Get-InstalledUpdates`

Utilitários de sistema cross-platform. `Test-IsWindows` e `Test-IsLinux` são utilizadas por todos os demais módulos como guard de plataforma.

| Função | Windows | Linux |
|--------|---------|-------|
| `Test-IsWindows` | retorna `$true` | retorna `$false` |
| `Test-IsLinux` | retorna `$false` | retorna `$true` |
| `Wait-UserInput` | pausa com Enter | pausa com Enter |
| `Get-SystemInformation` | hostname, OS, arch | + kernel via `uname -r` |
| `Get-SystemEnvironment` | SO, PS, usuário | SO, PS, usuário |
| `Get-InstalledUpdates` | Get-HotFix (últimos 20) | advisory |

---

### network.ps1

**Funções exportadas:** `Get-NetworkInformation`, `Test-NetworkConnectivity`, `Test-CommonPorts`

Diagnósticos de rede cross-platform.

| Função | Windows | Linux |
|--------|---------|-------|
| `Get-NetworkInformation` | `Get-NetIPAddress` + `Get-DnsClientServerAddress` | `ip -brief address` ou `ifconfig` + `/etc/resolv.conf` |
| `Test-NetworkConnectivity` | ping 8.8.8.8 + DNS google.com | ping 8.8.8.8 + DNS google.com |
| `Test-CommonPorts` | TcpClient localhost portas 53,80,443,445,3389,5985 | TcpClient localhost portas 53,80,443,445,3389,5985 |

---

### maintenance.ps1

**Funções exportadas:** `Clear-UserTempFiles`, `Get-StoppedImportantServices`

Manutenção básica. Ambas as funções exibem advisory no Linux sem executar ações.

| Função | Ação no Windows |
|--------|----------------|
| `Clear-UserTempFiles` | Remove arquivos de `$env:TEMP` com contagem de removidos/ignorados |
| `Get-StoppedImportantServices` | Verifica status de: WinRM, wuauserv, Spooler, EventLog, BITS |

---

### disk.ps1

**Funções exportadas:** `Get-DiskUsage`, `Get-LastBootTime`

| Função | Windows | Linux |
|--------|---------|-------|
| `Get-DiskUsage` | `Win32_LogicalDisk` (DriveType=3) | `df -h /` ou `Get-PSDrive` |
| `Get-LastBootTime` | `Win32_OperatingSystem.LastBootUpTime` | `uptime -s` ou `/proc/uptime` |

---

### triage.ps1

**Função exportada:** `Invoke-QuickMachineTriage`

Diagnóstico rápido consolidado em uma única tela. Seções:

1. **IDENTIFICAÇÃO** — hostname, OS, arquitetura, versão PS, usuário, domínio/workgroup (Windows) ou kernel (Linux)
2. **BOOT / UPTIME** — data do último boot e tempo de atividade
3. **REDE** — IPs e gateway (Windows) ou `ip -brief` (Linux)
4. **DISCO** — uso de C: (Windows) ou `/` (Linux)
5. **MEMÓRIA** — total, usado, livre
6. **TOP 5 PROCESSOS — MEMÓRIA** — by WorkingSet64
7. **TOP 5 PROCESSOS — CPU** — by CPU (segundos acumulados)

Funciona em Linux com dados disponíveis via PowerShell Core.

---

### corporate-network.ps1

**Função exportada:** `Test-CorporateNetworkHealth`

**Variável de módulo:** `$InternalDomainToTest` — deixar vazio para pular o teste de domínio interno.

Testes realizados:

| Teste | Método |
|-------|--------|
| Gateway padrão | `Get-NetRoute` (Win) / `ip route` (Linux) + `Test-Connection` |
| Ping 8.8.8.8 | `Test-Connection` |
| Ping 1.1.1.1 | `Test-Connection` |
| DNS google.com | `[System.Net.Dns]::GetHostAddresses` |
| TCP 80 google.com | `TcpClient.BeginConnect` timeout 2000ms |
| TCP 443 google.com | `TcpClient.BeginConnect` timeout 2000ms |
| DNS local porta 53 | `TcpClient.BeginConnect` timeout 1000ms |
| Domínio interno (opcional) | `[System.Net.Dns]::GetHostAddresses` |

---

### windows-health.ps1

**Funções exportadas:** `Test-EssentialWindowsServices`, `Get-HeavyUserFolders`, `Test-PendingReboot`, `Get-WindowsUpdateSummary`, `Get-BasicSecurityStatus`

Todas as funções exibem advisory no Linux sem lançar exceção.

| Função | Descrição |
|--------|-----------|
| `Test-EssentialWindowsServices` | Status de wuauserv, BITS, Spooler, WinRM, EventLog, W32Time, WinDefend |
| `Get-HeavyUserFolders` | Tamanho de Downloads, Desktop, Documents, TEMP usuário, Windows\Temp (verde <512MB, amarelo <2GB, vermelho ≥2GB) |
| `Test-PendingReboot` | Verifica 3 chaves de registro: CBS RebootPending, WU RebootRequired, PendingFileRenameOperations |
| `Get-WindowsUpdateSummary` | Últimos 10 hotfixes via `Get-HotFix`, ordenados por data |
| `Get-BasicSecurityStatus` | Defender (antivirus, proteção real-time, idade da assinatura), Firewall (3 perfis), BitLocker, UAC (registry EnableLUA) |

---

### evidence.ps1

**Função exportada:** `New-SupportEvidenceBundle`

Gera um bundle de evidências em `reports/Atlas_Evidence_yyyyMMdd_HHmmss/`:

| Arquivo | Conteúdo | Fonte |
|---------|----------|-------|
| `system.txt` | hostname, OS, arch, PS, usuário, uptime, memória | Gerado inline |
| `network.txt` | interfaces, DNS | `Get-NetworkInformation` |
| `disk.txt` | uso de disco | `Get-DiskUsage` |
| `services.txt` | status dos serviços essenciais | `Test-EssentialWindowsServices` |
| `security.txt` | Defender, Firewall, BitLocker, UAC | `Get-BasicSecurityStatus` |
| `summary.json` | objeto estruturado com metadados do bundle | `ConvertTo-Json` |

No Linux: `services.txt` e `security.txt` recebem mensagem explicativa; demais arquivos são coletados com dados disponíveis.

---

## Dependências entre Módulos

```
bootstrap/install.ps1
  ├── logger.ps1              (independente)
  ├── menu.ps1                (independente)
  ├── system.ps1              (usa: logger)
  ├── network.ps1             (usa: system, logger)
  ├── maintenance.ps1         (usa: system, logger)
  ├── disk.ps1                (usa: system, logger)
  ├── triage.ps1              (usa: system, logger)
  ├── corporate-network.ps1   (usa: system, logger)
  ├── windows-health.ps1      (usa: system, logger)
  └── evidence.ps1            (usa: system, network, disk, windows-health, logger)
```

> **Regra:** todos os módulos dependem de `system.ps1` (`Test-IsWindows`/`Test-IsLinux`) e `logger.ps1` (`Write-Log`). `install.ps1` deve dot-source `logger.ps1` e `system.ps1` antes de qualquer outro módulo.

---

## Fluxo Principal

```
bootstrap/install.ps1
  1. Dot-source módulos em ordem:
     logger → menu → system → network → maintenance → disk
     → triage → corporate-network → windows-health → evidence
  2. Write-Log "Atlas iniciado"
  3. Loop: while ($running)
     a. Show-MainMenu
     b. $option = Read-Host
     c. switch ($option)
        → chama a função correspondente
        → Wait-UserInput (pausa para leitura)
     d. "0" → $running = $false → encerra
```

---

## Padrões de Código

| Padrão | Descrição |
|--------|-----------|
| Verb-Noun PascalCase | Todas as funções públicas usam verbos aprovados pelo PowerShell |
| Guard de plataforma | `if (-not (Test-IsWindows))` com advisory e return antes de qualquer lógica exclusiva |
| `Write-Log` | Toda função pública registra execução (INFO) ou erros (ERROR/WARN) |
| `try/catch` | Obrigatório em toda chamada WMI/CIM, TcpClient, Registry e cmdlets opcionais |
| `Join-Path` | Todos os caminhos compostos usam `Join-Path` para compatibilidade cross-platform |
| `$running = $false` | Saída do loop principal — `break` dentro de `switch` não sai do loop externo |
| Variáveis antes de `-f` | Expressões `if` inline em strings de formato causam `ParserError` — atribuir à variável primeiro |

---

## Compatibilidade

| Plataforma | Nível |
|------------|-------|
| Windows 10/11 — PowerShell 5.1 (Desktop) | Completo |
| Windows 10/11 — PowerShell 7.x (Core) | Completo |
| Linux — PowerShell 7.x Core | Parcial — funções Windows-only exibem advisory, sem crash |
