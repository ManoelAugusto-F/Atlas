# Atlas — Auditoria Técnica Completa

**Data da auditoria:** 2026-06-09  
**Versão analisada:** v0.3.6 (`main`, commit `5c118a9` e posteriores)  
**Escopo:** Windows 11, PowerShell 5.1 / 7+, bootstrap online  
**Metodologia:** análise estática de código, leitura de configurações e testes não destrutivos  

---

## 1. RESUMO EXECUTIVO

### Estado geral do projeto

O Atlas é um assistente PowerShell modular, bem estruturado para suporte e manutenção Windows, com **16 módulos ativos** carregados pelo bootstrap, menu principal de 10 opções, histórico operacional em `ProgramData` e catálogo Winget com **47 programas** em **7 categorias**. A base é sólida para uso interno por técnicos familiarizados com PowerShell.

Porém, há **dívida técnica significativa**: 16 módulos legados não carregados, documentação desatualizada em relação ao comportamento real (especialmente Winget), bootstrap online sem pin de versão/hash, e funções carregadas sem exposição no menu (`quick-diagnostic`, `programs`, `services`).

### Pronto para uso real em Windows 11?

**Parcialmente.** Funciona para técnicos em ambiente controlado, com PowerShell elevado quando necessário e Winget instalado. **Não está pronto para distribuição ampla a terceiros** sem correções de segurança, alinhamento documentação/código e validação em máquinas reais.

### Principais riscos atuais

1. Bootstrap online baixa `main.zip` sem verificação de integridade — supply chain.
2. Padrão `irm | iex` documentado no README — execução remota direta.
3. Winget com saída suprimida (`*> $null`) — risco de falha silenciosa e falso sucesso.
4. README promete saída visual do Winget; código atual oculta tudo.
5. `Restart-ServiceSafe` sem confirmação, carregado no bootstrap mas sem menu.

### Principais pontos fortes

1. Arquitetura modular clara com validação de funções no bootstrap.
2. Confirmações consistentes na maioria das operações destrutivas.
3. Histórico operacional persistente em `C:\ProgramData\Atlas\Logs`.
4. Reparos Windows com diagnóstico guiado (`Start-WindowsDiagnostic`).
5. Testes automatizados cobrindo estrutura, imports e fluxos Winget por análise de arquivo.

### Recomendação geral

**Corrigir antes de usar** em produção ampla; **manter** como ferramenta interna com ressalvas; **refatorar** módulos legados e logging duplicado; **remover ou expor** funcionalidades mortas (`quick-diagnostic`, `programs`, `services`, `Export-SoftwareInventory`).

### Classificação geral

# **ATENÇÃO**

---

## 2. MAPA DO PROJETO

### Arquivos principais

| Arquivo | Função |
|---------|--------|
| `i.ps1` | Bootstrap online (cópia publicada via GitHub Pages / CNAME) |
| `online/install.ps1` | Idêntico a `i.ps1` |
| `bootstrap/install.ps1` | Entry point local: carrega módulos, loop do menu |
| `modules/*.ps1` | 33 arquivos (16 ativos + 16 legados + duplicatas conceituais) |
| `config/software-catalog.json` | Catálogo Winget (47 itens) |
| `tests/*.ps1` | 10 suites de teste |
| `README.md` | Documentação de produto |
| `VERSION.md` | Histórico de versões |

### Módulos ativos (carregados por `bootstrap/install.ps1`)

`logger.ps1`, `core.ps1`, `menu.ps1`, `quick-diagnostic.ps1`, `cleanup.ps1`, `network-tools.ps1`, `onedrive.ps1`, `printer.ps1`, `windows-repair.ps1`, `outlook.ps1`, `teams.ps1`, `browser.ps1`, `programs.ps1`, `services.ps1`, `software-install.ps1`, `history.ps1`

### Módulos legados (não carregados)

`health.ps1`, `diagnostics.ps1`, `inventory.ps1`, `evidence.ps1`, `disk.ps1`, `network.ps1`, `system.ps1`, `windows-health.ps1`, `corporate-network.ps1`, `triage.ps1`, `report.ps1`, `process.ps1`, `events.ps1`, `security.ps1`, `maintenance.ps1`, `config.ps1`

### Testes

| Arquivo | Foco |
|---------|------|
| `test_loop.ps1` | Imports, funções, simulação de menu |
| `test_logger.ps1` | Caminhos ProgramData, Write-AtlasLog |
| `test_history.ps1` | Histórico operacional |
| `test_software_install.ps1` | Catálogo, fluxo install, ausência de parsers |
| `test_software_upgrade.ps1` | Fluxo upgrade --all |
| `test_windows_repair.ps1` | Menu e funções de reparo |
| `test_winget_catalog.ps1` | Validação real de IDs (requer Windows + winget) |
| `test_imports.ps1` | Imports legados (desalinhado) |
| `test_v02_modules.ps1` | Módulos toolkit |
| `test_parser.ps1` | Sintaxe de módulos |

### Configurações

- `config/software-catalog.json` — catálogo principal
- `CNAME` — `a.bitsdeconhecimento.blog.br` → GitHub Pages

### Fluxo de execução online

```
Usuário
  → irm https://a.bitsdeconhecimento.blog.br/i.ps1 | iex
  → i.ps1 baixa main.zip do GitHub
  → extrai em %TEMP%\Atlas_<GUID>\
  → powershell.exe -ExecutionPolicy Bypass -File bootstrap\install.ps1
  → dot-source de 16 módulos
  → Initialize-AtlasLogger + Start-AtlasSessionLog
  → loop Show-MainMenu (opções 1–10, 0 sair)
  → finally: Remove-Item TEMP (i.ps1)
  → finally: Stop-AtlasSessionLog (bootstrap)
```

---

## 3. ANÁLISE DO BOOTSTRAP ONLINE

**Arquivos:** `i.ps1`, `online/install.ps1` (conteúdo idêntico)

### O que funciona

| Item | Status |
|------|--------|
| Baixa ZIP via `Invoke-WebRequest` | OK |
| Executa em `%TEMP%\Atlas_<GUID>` | OK |
| Valida ZIP não vazio | OK |
| `Expand-Archive` + localiza `bootstrap\install.ps1` | OK |
| `finally` remove pasta TEMP | OK |
| Funciona sem Git instalado | OK |
| Funciona sem instalação permanente | OK |

### Problemas

| Item | Classificação |
|------|---------------|
| URL fixa em `refs/heads/main.zip` — sempre última versão da branch | **ATENÇÃO** |
| Sem validação de hash/assinatura do ZIP | **ATENÇÃO** |
| `-ExecutionPolicy Bypass` no subprocesso | **ATENÇÃO** |
| Sem fallback se `Expand-Archive` indisponível | OK (erro claro) |
| Sem retry em falha de rede | ATENÇÃO |
| README recomenda `irm \| iex` | **CRÍTICO** (superfície de ataque se URL comprometida) |

### Recomendações futuras (não implementar agora)

- Pin por tag/release (`refs/tags/vX.Y.Z.zip`)
- Checksum SHA256 publicado
- Considerar `-ExecutionPolicy RemoteSigned`
- Mensagem explícita de versão baixada

### Classificação

# **ATENÇÃO**

---

## 4. ANÁLISE DO MENU PRINCIPAL

**Arquivo:** `modules/menu.ps1` + `bootstrap/install.ps1`

### Opções atuais

| # | Opção | Destino |
|---|-------|---------|
| 1 | Limpeza segura | `Show-CleanupMenu` |
| 2 | Rede e internet | `Show-NetworkMenu` |
| 3 | OneDrive | `Show-OneDriveMenu` |
| 4 | Impressoras | `Show-PrinterMenu` |
| 5 | Reparos Windows | `Show-WindowsRepairMenu` |
| 6 | Outlook | `Show-OutlookMenu` |
| 7 | Teams | `Show-TeamsMenu` |
| 8 | Navegadores | `Show-BrowserMenu` |
| 9 | Instalação de programas | `Show-SoftwareInstallMenu` |
| 10 | Histórico do Atlas | `Show-HistoryMenu` |
| 0 | Sair | Encerra loop |

### Pontos positivos

- Menu compacto e centralizado (`Show-AtlasHeader`, opções numeradas).
- Ordem lógica: manutenção → apps → instalação → histórico.
- Submenus seguem padrão visual consistente.
- Reparos Windows usa opções descritivas com nível de risco.

### Problemas

| Problema | Impacto |
|----------|---------|
| Sem indicação de “requer administrador” no menu principal | Usuário leigo pode falhar em SFC/DISM/rede |
| Opção 9 mistura instalar e atualizar (submenu) | Pode confundir leigos |
| `quick-diagnostic` removido do menu mas ainda carregado | Expectativa de diagnóstico rápido perdida |
| README cita funcionalidades Winget que não correspondem ao código | Expectativa incorreta |
| Nenhuma opção de “inventário” ou “programas instalados” apesar de módulos existirem | Funcionalidade oculta |

### Risco de escolha errada

**Médio.** Usuário leigo pode entrar em Reparos Windows ou Rede sem entender impacto. Submenus de Reparos têm descrições, mas menu principal não alerta.

### Melhorias sugeridas

- Badge “Admin” nas opções 1, 4, 5, 9.
- Reunificar documentação README com comportamento real.
- Expor diagnóstico rápido ou remover do bootstrap.
- Texto de ajuda na opção 9 explicando que Winget não mostra progresso.

### Classificação

# **OK** (com ressalvas de UX para leigos)

---

## 5. ANÁLISE POR MÓDULO

---

### core.ps1

**Arquivo:** `modules/core.ps1`

**Funções principais:**
- `Show-AtlasHeader`, `Show-AtlasCompactOption`, `Show-AtlasDescribedOption`, `Show-AtlasBackOption`
- `Read-AtlasMenuChoice`, `Read-AtlasConfirm`
- `Write-AtlasInfo`, `Write-AtlasSuccess`, `Write-AtlasWarning`, `Write-AtlasError`
- `Write-AtlasStep`, `Write-AtlasProgress`, `Write-AtlasResult`
- `Wait-UserInput`, `Show-FeaturePlaceholder`

**O que entrega:** Camada de UI/UX padronizada para todos os menus.

**Pontos positivos:**
- Centralização de cores e layout.
- Helpers de confirmação reutilizáveis.

**Problemas encontrados:**
- `Write-AtlasStep/Progress/Result` pouco usados após mudanças no Winget.
- `Show-FeaturePlaceholder` praticamente legado.

**Riscos:** Baixos.

**Melhorias sugeridas:** Remover helpers não utilizados ou documentar quando usar.

**Classificação:** **OK**

---

### logger.ps1

**Arquivo:** `modules/logger.ps1`

**Funções principais:**
- `Initialize-AtlasLogger`, `Write-AtlasLog`, `Get-AtlasLogPath`
- `Start-AtlasSessionLog`, `Write-AtlasSessionLog`, `Stop-AtlasSessionLog`
- `Write-Log` (legado → `provisionador.log`)

**O que entrega:** Log operacional em `C:\ProgramData\Atlas\Logs\atlas.log` e sessão em `Sessions\session_*.log`.

**Pontos positivos:**
- Caminho canônico em ProgramData no Windows.
- Fallback para TEMP em não-Windows (dev/teste).
- `catch {}` evita quebra por falha de escrita.

**Problemas encontrados:**
- **Dois arquivos de log:** `atlas.log` + `provisionador.log`.
- `Write-Log` ainda usado amplamente; `Write-AtlasLog` em paralelo — duplicidade.
- Falhas de escrita silenciadas (`catch {}`).
- `test_logger.ps1` falha em Linux quando `$env:ProgramData` está vazio.

**Riscos:**
- Perda de auditoria se ProgramData sem permissão.
- Confusão sobre qual log consultar.

**Melhorias sugeridas:** Unificar em `atlas.log`; deprecar `provisionador.log`; logar falha de escrita uma vez.

**Classificação:** **ATENÇÃO**

---

### history.ps1

**Arquivo:** `modules/history.ps1`

**Funções principais:**
- `Get-AtlasRecentLogs`, `Open-AtlasLogFolder`, `Clear-AtlasLogs`, `Show-HistoryMenu`

**O que entrega:** Consulta dos últimos 50 eventos, abertura da pasta de logs, limpeza com confirmação.

**Pontos positivos:**
- Confirmação antes de limpar histórico.
- Integração simples com `Get-AtlasLogPath`.

**Problemas encontrados:**
- `Clear-AtlasLogs` limpa apenas `atlas.log`, não sessões nem `provisionador.log`.
- Sem rotação automática de logs.

**Riscos:** Baixos.

**Melhorias sugeridas:** Opção para limpar sessões antigas; mostrar caminho completo.

**Classificação:** **OK**

---

### cleanup.ps1

**Arquivo:** `modules/cleanup.ps1`

**Funções principais:**
- `Get-LargestUserFolders`, `Get-LargestUserFiles`
- `Clear-UserTemp`, `Clear-WindowsTemp`, `Clear-WindowsUpdateCache`, `Clear-RecycleBinSafe`
- `Invoke-SafeCleanup`, `Show-CleanupMenu`

**O que entrega:** Limpeza segura de temporários, cache WU e lixeira.

**Pontos positivos:**
- Confirmação por ação e na limpeza completa.
- Proteção de pastas `Atlas_*` em TEMP.
- Checagem de admin para operações sensíveis.

**Problemas encontrados:**
- `Remove-Item -Recurse -Force` — risco inerente se paths errados.
- Limpeza WU pode impactar updates em andamento.

**Riscos:** Médios — operação destrutiva com salvaguardas.

**Melhorias sugeridas:** Estimativa de espaço liberado antes de confirmar.

**Classificação:** **OK**

---

### network-tools.ps1

**Arquivo:** `modules/network-tools.ps1`

**Funções principais:**
- `Test-InternetConnectionBasic`, `Test-DnsBasic`, `Get-NetworkConfigBasic`
- `Clear-DnsCacheSafe`, `Update-IpAddressLeaseSafe`, `Reset-WinsockSafe`, `Reset-TcpIpSafe`
- `Show-NetworkMenu`

**O que entrega:** Diagnóstico e correções de rede com confirmação.

**Pontos positivos:**
- Todas ações destrutivas pedem confirmação.
- Testes de conectividade antes de resets agressivos.

**Problemas encontrados:**
- **Sem verificação explícita de privilégio de administrador** para `netsh winsock reset`, `netsh int ip reset`, `ipconfig /release`.
- Pode falhar silenciosamente ou parcialmente sem admin.

**Riscos:**
- Queda temporária de rede após reset Winsock/TCP.
- Renew IP pode desconectar VPN.

**Melhorias sugeridas:** `Test-RepairAdmin` equivalente; aviso de desconexão.

**Classificação:** **ATENÇÃO**

---

### onedrive.ps1

**Arquivo:** `modules/onedrive.ps1`

**Funções principais:**
- `Get-OneDriveStatus`, `Restart-OneDriveSafe`, `Reset-OneDriveSafe`
- `Uninstall-OneDriveSafe`, `Clear-OneDriveResidualFilesSafe`
- `Open-OneDriveFolder`, `Open-OneDriveLogs`, `Open-OneDriveDownloadPage`
- `Show-OneDriveMenu`

**O que entrega:** Ciclo completo de suporte OneDrive.

**Pontos positivos:**
- Confirmações em reset, desinstalação e limpeza de resíduos.
- Logging detalhado.

**Problemas encontrados:**
- Desinstalação pode exigir admin não verificado.
- `Stop-Process -Force` em OneDrive.

**Riscos:** Médios — perda temporária de sync.

**Melhorias sugeridas:** Verificar sync pendente antes de reset.

**Classificação:** **OK**

---

### printer.ps1

**Arquivo:** `modules/printer.ps1`

**Funções principais:**
- `Get-PrinterList`, `Get-PrintQueueStatus`, `Get-PrinterDrivers`
- `Restart-SpoolerSafe`, `Clear-PrintQueueSafe`
- `Add-TcpIpPrinterSafe`, `Add-SharedPrinterSafe`
- `Show-PrinterMenu`

**O que entrega:** Diagnóstico e correção de impressão.

**Pontos positivos:**
- Checagem de admin para Spooler e fila.
- Confirmação antes de ações críticas.

**Problemas encontrados:**
- Adicionar impressora TCP/IP sem validação avançada de driver.

**Riscos:** Médios — fila limpa pode perder jobs.

**Melhorias sugeridas:** Listar jobs antes de limpar fila.

**Classificação:** **OK**

---

### windows-repair.ps1

**Arquivo:** `modules/windows-repair.ps1`

**Funções principais:**
- `Test-SfcVerifyOnly`, `Invoke-SfcScannowSafe`
- `Test-DismCheckHealth`, `Invoke-DismScanHealthSafe`, `Invoke-DismRestoreHealthSafe`
- `Reset-WindowsUpdateSafe`, `Start-WindowsDiagnostic`
- `Show-WindowsRepairMenu`

**O que entrega:** SFC, DISM, reset WU e diagnóstico guiado.

**Pontos positivos:**
- Verificação de admin implementada.
- Confirmação em operações longas/destrutivas.
- Diagnóstico guiado com recomendações.

**Problemas encontrados:**
- Reset WU renomeia `SoftwareDistribution` — impacto em updates.
- Operações podem levar horas; usuário só vê “Aguarde”.

**Riscos:** Altos se usado sem entendimento — mas mitigados por confirmação.

**Melhorias sugeridas:** Tempo estimado; aviso de reinicialização.

**Classificação:** **OK**

---

### outlook.ps1

**Arquivo:** `modules/outlook.ps1`

**Funções principais:**
- `Get-OutlookStatus`, `Restart-OutlookSafe`, `Restart-OutlookProcess`
- `Clear-OutlookRoamCacheSafe`, `Open-OfficeRepairPanel`
- `Open-InstalledAppsForOffice`, `Open-OfficeDownloadPage`
- `Show-OutlookMenu`

**O que entrega:** Toolkit Outlook/Office.

**Pontos positivos:**
- Cache RoamCache com confirmação.
- Atalhos para reparo oficial Microsoft.

**Problemas encontrados:**
- `Restart-OutlookProcess` usa `-Force` **sem confirmação** (chamada interna).
- Pode encerrar Outlook com e-mail não salvo.

**Riscos:** Médios.

**Melhorias sugeridas:** Unificar restart com confirmação sempre.

**Classificação:** **ATENÇÃO**

---

### teams.ps1

**Arquivo:** `modules/teams.ps1`

**Funções principais:**
- `Get-TeamsStatus`, `Restart-TeamsSafe`, `Clear-TeamsCacheSafe`
- `Remove-TeamsPersonalSafe`, `Get-TeamsPersonalStatus`, `Get-TeamsWorkSchoolStatus`
- `Show-TeamsMenu`

**O que entrega:** Suporte Teams clássico/moderno.

**Pontos positivos:**
- Remoção Teams pessoal exige digitar `SIM`.
- Limpeza de cache com confirmação.

**Problemas encontrados:**
- `Restart-TeamsSafe` **encerra mas não reinicia** Teams — mensagem enganosa (“sera reiniciado”).
- `Clear-TeamsCache` interna sem confirmação direta (só via `Clear-TeamsCacheSafe`).

**Riscos:** Baixos a médios.

**Melhorias sugeridas:** Corrigir nomenclatura; relançar Teams após stop.

**Classificação:** **ATENÇÃO**

---

### browser.ps1

**Arquivo:** `modules/browser.ps1`

**Funções principais:**
- `Get-BrowserProfiles`, `Get-BrowserStatus`
- `Clear-ChromeCacheSafe`, `Clear-EdgeCacheSafe`, `Clear-FirefoxCacheSafe`, `Clear-AllBrowserCachesSafe`
- `Open-BrowserProfileFolder`, `Show-BrowserMenu`

**O que entrega:** Limpeza de cache e perfis de navegadores.

**Pontos positivos:**
- Confirmação em todas limpezas.
- Suporte Chrome, Edge, Firefox.

**Problemas encontrados:**
- Cache limpo pode deslogar sites.
- Brave listado no catálogo mas não no menu de navegadores.

**Riscos:** Baixos.

**Melhorias sugeridas:** Aviso sobre sessões logadas.

**Classificação:** **OK**

---

### software-install.ps1

**Arquivo:** `modules/software-install.ps1`

**Funções principais:**
- `Get-SoftwareCatalog`, `Show-SoftwareInstallMenu`, `Install-SoftwareByWingetSafe`
- `Update-InstalledSoftwareSafe`, `Install-RsatFullSafe`
- `Show-Microsoft365Menu`, `Test-WingetCatalogItem`, `Invoke-WingetCatalogValidation`
- `Get-WingetAvailableUpgrades`, `Export-SoftwareInventory` (sem menu)

**O que entrega:** Instalação e atualização via Winget + RSAT + M365.

**Pontos positivos:**
- Confirmação antes de install/upgrade.
- Mensagens de sucesso/falha claras com comando manual.
- Catálogo JSON organizado.
- Sem parser JSON de saída Winget (estável).

**Problemas encontrados:**
- Saída Winget suprimida (`*> $null`).
- README/VERSION descrevem saída visual — **drift documental**.
- `Get-WingetAvailableUpgrades` existe mas não é usada no fluxo de atualização.
- `Export-SoftwareInventory` órfã (sem menu).
- Três versões SSMS no catálogo.
- M365 no catálogo winget + submenu especial — duplicidade.

**Riscos:**
- Falso sucesso se `$LASTEXITCODE` não refletir falha parcial.
- Instalação silenciosa dificulta suporte.

**Melhorias sugeridas:** Ver seção 6.

**Classificação:** **ATENÇÃO**

---

### menu.ps1

**Arquivo:** `modules/menu.ps1`

**Funções principais:**
- `Show-MainMenu`

**O que entrega:** Menu principal compacto.

**Pontos positivos:** Simples, delega para submenus.

**Problemas encontrados:** Sem descrições no menu principal.

**Riscos:** Baixos.

**Melhorias sugeridas:** Subtítulo com versão do Atlas.

**Classificação:** **OK**

---

## 6. ANÁLISE DO WINGET

**Arquivos:** `modules/software-install.ps1`, `config/software-catalog.json`

### Catálogo

| Métrica | Valor |
|---------|-------|
| Categorias | 7 |
| Itens | 47 |
| Winget | 46 |
| Special (RSAT) | 1 |

**Coerência:** Boa organização por categoria. IDs corrigidos em v0.3.1 (WinBox, DBeaver, SSMS).

**Problemas do catálogo:**
- 3 entradas SSMS (20, 21, 22) — risco de confusão/duplicação.
- Pacotes pesados (Docker, WSL, RSAT) sem aviso no JSON.
- Validação real só com `test_winget_catalog.ps1` em Windows.

### Fluxo de instalação (estado atual)

```powershell
& winget install --id $PackageId --exact --accept-source-agreements --accept-package-agreements *> $null
$exitCode = $LASTEXITCODE
```

- Confirmação única antes de executar.
- Mensagem “Instalando X. Aguarde...”.
- Sucesso/falha baseado apenas em exit code.
- Em falha: mostra comando manual.

### Fluxo de atualização (estado atual)

```powershell
& winget upgrade --all --accept-source-agreements --accept-package-agreements *> $null
$exitCode = $LASTEXITCODE
```

- Sem listagem prévia de pacotes.
- Confirmação única.
- Sem progresso visual.

### Respostas às perguntas da auditoria

| Pergunta | Resposta |
|----------|----------|
| Catálogo coerente? | Sim, com ressalvas (SSMS triplicado) |
| IDs corretos? | Provavelmente sim (validados em v0.3.1); revalidar periodicamente |
| Instalação estável? | Sim — abordagem simples, sem parser |
| Atualização estável? | Sim — mas sem visibilidade do que será atualizado |
| UX boa? | **Regular** — usuário não vê progresso nem detalhes |
| Winget usado corretamente? | Parcialmente — flags corretas, mas saída oculta |
| Parser perigoso? | **Não** — removido |
| Captura ruim de saída? | **Sim** — `*> $null` descarta tudo |
| Comando oculta erro? | **Sim** — erros do winget não aparecem |
| Risco de falso sucesso? | **Médio** — depende de exit code do winget |
| Risco de falha silenciosa? | **Alto** para diagnóstico; baixo para decisão binária OK/ERRO |

### Funções removidas (confirmado)

- `Invoke-WingetWithLoading` — ausente
- `Invoke-WingetVisible` — ausente
- `Parse-WingetUpgradeList` — ausente
- Parsers JSON — ausentes

### Função subutilizada

- `Get-WingetAvailableUpgrades` — roda `winget upgrade` silenciosamente, não integrada ao menu de atualização.

### Classificação Winget

# **ATENÇÃO**

---

## 7. ANÁLISE DE LOGS E HISTÓRICO

### Locais

| Caminho | Uso | Status |
|---------|-----|--------|
| `C:\ProgramData\Atlas\Logs\atlas.log` | Histórico operacional (`Write-AtlasLog`) | **Canônico** |
| `C:\ProgramData\Atlas\Logs\Sessions\session_*.log` | Log de sessão detalhado | **Canônico** |
| `C:\ProgramData\Atlas\Logs\provisionador.log` | `Write-Log` legado | **Duplicado** |
| `%TEMP%\Atlas_*` | Bootstrap online | Temporário |
| `logs/provisionador.log` (repo) | Artefato legado commitado | **Obsoleto** |

### Persistência

- Logs persistem entre execuções em ProgramData.
- Sessões acumulam sem rotação automática.

### Permissões

- Escrita em ProgramData geralmente requer permissões adequadas; código usa `catch {}` se falhar.

### Limpeza

- `Clear-AtlasLogs` limpa só `atlas.log`.
- Sem política de retenção.

### Atlas ainda grava em TEMP?

- Bootstrap: sim, temporariamente.
- Logger em não-Windows: fallback TEMP.
- Em Windows 11 produção: **ProgramData**.

### Risco de log quebrar execução

**Baixo** — falhas silenciadas.

### Classificação

# **ATENÇÃO**

---

## 8. ANÁLISE DE SEGURANÇA

| Área | Avaliação |
|------|-----------|
| Operações destrutivas pedem confirmação? | **Maioria sim** — exceção: `Restart-ServiceSafe` |
| Risco de apagar arquivo pessoal? | **Baixo** — cleanup limitado a temp/cache/lixeira |
| Risco de quebrar rede? | **Médio** — resets Winsock/TCP com confirmação |
| Risco reset Windows Update? | **Médio** — confirmação + admin |
| Risco instalação software? | **Médio** — winget oficial, mas sem revisão de pacote |
| Execução remota segura? | **Baixa** — `irm \| iex` + main.zip sem hash |
| Validação de origem? | **Ausente** |
| main.zip sem hash? | **Sim — CRÍTICO para supply chain** |
| Risco em `irm \| iex`? | **Alto** se endpoint comprometido |

### Classificação

# **ATENÇÃO** (bootstrap: **CRÍTICO**)

---

## 9. ANÁLISE DE COMPATIBILIDADE WINDOWS 11

| Requisito | Status |
|-----------|--------|
| Windows PowerShell 5.1 | Suportado |
| PowerShell 7+ | Suportado |
| Winget | Obrigatório para instalação/atualização |
| ProgramData | Usado corretamente |
| UAC | Parcialmente tratado (alguns módulos checam admin) |
| App Installer | Necessário para winget |

### Funções que exigem administrador

| Módulo | Função | Admin |
|--------|--------|-------|
| cleanup | `Clear-WindowsTemp`, `Clear-WindowsUpdateCache` | Sim |
| windows-repair | SFC scannow, DISM restore, Reset WU | Sim |
| printer | Spooler, fila | Sim |
| software-install | `Install-RsatFullSafe` | Sim |
| network-tools | netsh, ipconfig release | Recomendado (não verificado) |

### Classificação

# **OK** (com gaps de verificação de admin em rede)

---

## 10. CÓDIGO MORTO, DUPLICADO OU SUSPEITO

### Funções/módulos não utilizados no runtime

| Item | Detalhe |
|------|---------|
| 16 módulos legados | Não carregados pelo bootstrap |
| `quick-diagnostic.ps1` | Carregado, **sem menu** |
| `programs.ps1` | Carregado, **sem menu** |
| `services.ps1` | Carregado, **sem menu** |
| `Export-SoftwareInventory` | Função existe, **sem menu** |
| `Get-WingetAvailableUpgrades` | Não usada no fluxo de atualização |
| `Show-FeaturePlaceholder` | Legado |
| `Write-AtlasStep/Progress/Result` | Subutilizados |

### Parsers antigos Winget

- **Removidos** — confirmado por testes e grep.

### Referências a relatório removido

- `support-report.ps1` — **arquivo ausente**
- Referências em `VERSION.md`, `docs/ROADMAP.md`, `docs/RELEASE_v0.1.md`
- `evidence.ps1`, `inventory.ps1` — órfãos do relatório

### Logs antigos

- `logs/provisionador.log` no repositório
- `Write-Log` → `provisionador.log` em ProgramData
- Docs antigas citam `logs/sessions/`

### Duplicações

| Área | Duplicação |
|------|------------|
| SFC/DISM | `health.ps1` vs `windows-repair.ps1` |
| Rede | `network.ps1` vs `network-tools.ps1` |
| Limpeza | `maintenance.ps1` vs `cleanup.ps1` |
| Catálogo | `config.ps1` vs `software-catalog.json` |
| Wait-UserInput | `core.ps1` vs `system.ps1` |
| Microsoft 365 | Catálogo winget + submenu dedicado |

### Testes órfãos/desalinhados

- `test_imports.ps1` — não inclui `history.ps1`, lista funções antigas
- `test_parser.ps1` — validação sintática legada

---

## 11. TESTES EXISTENTES

### Inventário

| Teste | Valida | Não valida | Utilidade | Fragilidade |
|-------|--------|------------|-----------|-------------|
| `test_loop.ps1` | Imports, funções, leituras básicas | Comportamento real Windows | **Alta** | Média (Linux simula) |
| `test_logger.ps1` | ProgramData, atlas.log, sessões | Cenários sem ProgramData | **Alta** | **Alta** — falha se `$env:ProgramData` vazio |
| `test_history.ps1` | Get/Clear logs, integração | UI interativa | **Média** | Baixa |
| `test_software_install.ps1` | Catálogo, fluxo install, anti-patterns | Execução winget real | **Alta** | Baixa (análise estática) |
| `test_software_upgrade.ps1` | Fluxo upgrade --all | Execução winget real | **Alta** | Baixa |
| `test_windows_repair.ps1` | Menu descritivo, funções | SFC/DISM real | **Alta** | Baixa |
| `test_winget_catalog.ps1` | IDs winget reais | — | **Alta** (Windows) | Requer winget + rede |
| `test_imports.ps1` | Imports legados | Bootstrap atual | **Baixa** | Desatualizado |
| `test_v02_modules.ps1` | Toolkit modules | — | **Média** | Baixa |
| `test_parser.ps1` | Sintaxe | Semântica | **Baixa** | Baixa |

### Testes executados nesta auditoria

| Teste | Resultado | Ambiente |
|-------|-----------|----------|
| `test_loop.ps1` | ✅ SUCESSO | Linux / pwsh |
| `test_logger.ps1` | ❌ FALHA | Linux — `$env:ProgramData` vazio |
| `test_history.ps1` | ✅ SUCESSO | Linux / pwsh |
| `test_software_install.ps1` | ✅ SUCESSO | Linux / pwsh |
| `test_software_upgrade.ps1` | ✅ SUCESSO | Linux / pwsh |
| `test_windows_repair.ps1` | ✅ SUCESSO | Linux / pwsh |

### Testes a criar (sugestão)

- Bootstrap online (mock de download)
- Verificação de admin em network-tools
- Teste de `Restart-ServiceSafe` exigir confirmação
- Alinhamento `test_imports` com bootstrap atual
- Teste de drift README vs código Winget

---

## 12. BUGS PROVÁVEIS

| Severidade | Área | Problema | Impacto | Sugestão |
|------------|------|----------|---------|----------|
| **Crítica** | Bootstrap | `main.zip` sem hash/assinatura | Execução de código alterado | Pin por release + SHA256 |
| **Crítica** | Documentação | README promete saída visual Winget | Expectativa incorreta do usuário | Atualizar README |
| **Alta** | Winget | `*> $null` oculta erros | Falha silenciosa, suporte difícil | Manter exit code; opcional log em arquivo só em falha |
| **Alta** | Teams | `Restart-TeamsSafe` não reinicia | Usuário acha que Teams voltou | Relançar executável ou renomear função |
| **Alta** | Logger | `test_logger` falha sem ProgramData | CI/Linux quebra | Guard clause no teste |
| **Média** | Rede | Sem checagem admin | Comando falha sem explicação clara | Test-NetworkAdmin |
| **Média** | Outlook | `Restart-OutlookProcess -Force` sem confirmação | Perda de trabalho não salvo | Exigir confirmação |
| **Média** | Histórico | `Clear-AtlasLogs` não limpa sessões | Logs antigos permanecem | Limpar ou documentar |
| **Média** | VERSION | v0.3.6 descreve features não presentes | Confusão de release | Sincronizar changelog |
| **Baixa** | Catálogo | 3 SSMS | Instalação duplicada | Consolidar para versão atual |
| **Baixa** | services | `Restart-ServiceSafe` sem confirmação | Reinício acidental se exposto | Confirmação ou remover do bootstrap |

---

## 13. PRIORIZAÇÃO DE CORREÇÕES

### Corrigir imediatamente

1. Alinhar **README** e **VERSION.md** com comportamento real do Winget.
2. Avaliar risco de **falso sucesso** no Winget — considerar log em arquivo apenas em falha.
3. **Bootstrap online:** pin de versão ou tag estável.
4. Remover ou proteger **`Restart-ServiceSafe`** (confirmação).
5. Corrigir **`Restart-TeamsSafe`** — mensagem/comportamento.

### Corrigir em seguida

1. Unificar logging (`atlas.log` vs `provisionador.log`).
2. Verificação de admin em `network-tools.ps1`.
3. Atualizar `test_imports.ps1` e corrigir `test_logger.ps1` para ambientes sem ProgramData.
4. Remover ou expor `quick-diagnostic`, `programs`, `services` no menu.
5. Decidir destino de `Get-WingetAvailableUpgrades` e `Export-SoftwareInventory`.

### Melhorias futuras

1. Arquivar 16 módulos legados em `legacy/`.
2. Rotação/limpeza automática de logs de sessão.
3. Badge “Admin” no menu principal.
4. Revalidação periódica do catálogo Winget (CI com `test_winget_catalog`).
5. Checksum no bootstrap; assinatura de release.

---

## 14. RECOMENDAÇÃO DE ROADMAP

### Fase 1 — Estabilização (1–2 sprints)

- Congelar comportamento Winget e documentar definitivamente.
- Corrigir drift documentação/código.
- Hardening do bootstrap (tag + hash).
- Fechar lacunas de confirmação (Teams, Outlook, services).

### Fase 2 — Consolidação (2–3 sprints)

- Unificar logging.
- Remover código morto (módulos legados).
- Alinhar todos os testes ao bootstrap atual.
- Validar em 3+ máquinas Windows 11 reais (usuário padrão + admin).

### Fase 3 — UX e segurança (contínuo)

- Indicadores de privilégio no menu.
- Mensagens de tempo estimado em SFC/DISM/Winget.
- Política de retenção de logs.
- Release notes automáticas por tag.

**Não recomendar interface gráfica neste momento** — o valor do Atlas está no terminal para técnicos; GUI aumentaria superfície sem ganho proporcional agora.

---

## 15. CONCLUSÃO

### Atlas está pronto para uso por terceiros?

**Não completamente.** Adequado para técnicos internos com orientação. Para terceiros ou MSPs, corrigir bootstrap, documentação e transparência do Winget antes.

### O que corrigir antes?

1. Documentação (README/VERSION) vs código Winget.
2. Segurança do bootstrap online.
3. Comportamento enganoso em Teams restart.
4. Funções carregadas sem menu e sem confirmação (`services`).

### Módulo mais crítico

**`software-install.ps1` + bootstrap online** — instala software e é o vetor de distribuição remota.

### Módulo que entrega mais valor

**`windows-repair.ps1`** — diagnóstico guiado + SFC/DISM + reset WU, com confirmações e integração de log.

### Módulo que deve ser simplificado

**`software-install.ps1`** — remover funções órfãs (`Get-WingetAvailableUpgrades`, `Export-SoftwareInventory` do runtime ou expor no menu), consolidar SSMS e M365, alinhar UX com política final de Winget.

---

## Apêndice A — Parecer do auditor

O Atlas evoluiu de um provisionador genérico para uma ferramenta focada em Windows 11 com boa disciplina modular. A remoção de parsers Winget e relatório HTML simplificou o produto. O maior risco atual não é código quebrado no menu principal, mas **expectativa vs realidade** (documentação, Winget silencioso) e **distribuição remota sem pin de versão**.

**Veredito final: ATENÇÃO — usar com ressalvas; corrigir itens imediatos antes de promover amplamente.**

---

*Documento gerado por auditoria estática. Nenhum código-fonte foi alterado durante esta análise.*
