# Atlas v0.1

**Data de release:** 2026-05-29
**Branch:** main

---

## Módulos

| Grupo | Arquivo | Funções |
|-------|---------|---------|
| Inventário | `modules/system.ps1` | `Get-SystemInformation`, `Get-SystemEnvironment`, `Get-InstalledUpdates` |
| Rede | `modules/network.ps1` | `Get-NetworkInformation`, `Test-NetworkConnectivity`, `Test-CommonPorts` |
| Disco | `modules/disk.ps1` | `Get-DiskUsage`, `Get-LastBootTime` |
| Manutenção | `modules/maintenance.ps1` | `Clear-UserTempFiles`, `Get-StoppedImportantServices` |
| Triagem | `modules/triage.ps1` | `Invoke-QuickMachineTriage` |
| Rede Corporativa | `modules/corporate-network.ps1` | `Test-CorporateNetworkHealth` |
| Saúde Windows | `modules/windows-health.ps1` | `Test-EssentialWindowsServices`, `Get-HeavyUserFolders`, `Test-PendingReboot`, `Get-WindowsUpdateSummary`, `Get-BasicSecurityStatus` |
| Evidências | `modules/evidence.ps1` | `New-SupportEvidenceBundle` |

**Total: 10 módulos, 19 funções públicas**

---

## Histórico

### v0.1 — 2026-05-29

- Arquitetura modular consolidada com 10 módulos independentes
- 19 funções públicas seguindo padrão Verb-Noun PascalCase
- Menu interativo com 14 opções de diagnóstico e suporte
- Compatibilidade cross-platform (Windows completo / Linux parcial)
- Coleta de bundle de evidências em `reports/Atlas_Evidence_*/`
- Log centralizado em `logs/provisionador.log`
- Testes automatizados via `tests/test_loop.ps1`
