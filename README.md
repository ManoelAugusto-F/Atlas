# Atlas - Assistente de Manutencao Windows v0.2.4

O **Atlas** e um assistente interativo e modular desenvolvido em PowerShell, focado no diagnostico preventivo, triagem rapida e correcao de estacoes de trabalho. Desenvolvido sob rigorosos criterios de compatibilidade, o Atlas e 100% compativel com o **Windows PowerShell 5.1** e **PowerShell Core 7+** (cross-platform, com simulacoes seguras em ambiente nao-Windows).

**Versao Atual**: v0.2.4 — Validacao do catalogo winget (teste + relatorio HTML), instalacao com barra de progresso visivel e Microsoft 365 via portal corporativo.

---

## Estrutura do Workspace

* [bootstrap/install.ps1](bootstrap/install.ps1) — Script principal de carregamento (bootstrapper) que carrega os modulos e gerencia a interatividade.
* [config/apps.json](config/apps.json) — Arquivo de configuracao estruturado para aplicacoes e atalhos.
* [config/software-catalog.json](config/software-catalog.json) — Catalogo de programas por categoria (winget e acoes especiais).
* [logs/sessions/](logs/sessions/) — Log persistente por sessao do Atlas (`session_yyyyMMdd_HHmmss.log`).
* [docs/](docs/) — Pasta com documentacoes oficiais de arquitetura, escopo, roadmap e testes.
  * [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Documentacao da arquitetura modular e diretrizes tecnicas.
  * [docs/PRODUCT_SCOPE.md](docs/PRODUCT_SCOPE.md) — Escopo do produto, restricoes de negocio e publico-alvo.
  * [docs/RELEASE_v0.1.md](docs/RELEASE_v0.1.md) — Notas de lancamento oficiais da versao v0.1.0.
  * [docs/ROADMAP.md](docs/ROADMAP.md) — Defricao do ciclo de vida, sprints (v0.1, v0.2, v0.3, v1.0) e gantt de marcos.
  * [docs/WINDOWS_TESTS.md](docs/WINDOWS_TESTS.md) — Matriz de testes de conformidade e validacoes no Windows.
  * [docs/ISSUES.md](docs/ISSUES.md) — Registro de demandas tecnicas e status das atividades (Sprint v0.2).
* [modules/](modules/) — Modulos e bibliotecas tecnicas isoladas do sistema:
  * **Core**: [modules/logger.ps1](modules/logger.ps1) (sistema de logs), [modules/core.ps1](modules/core.ps1) (helpers de confirmacao e UX), [modules/menu.ps1](modules/menu.ps1) (gerador de console e menus).
  * **Manutencao e Diagnostico v0.1**: [modules/quick-diagnostic.ps1](modules/quick-diagnostic.ps1), [modules/cleanup.ps1](modules/cleanup.ps1), [modules/network-tools.ps1](modules/network-tools.ps1), [modules/onedrive.ps1](modules/onedrive.ps1), [modules/printer.ps1](modules/printer.ps1), [modules/windows-repair.ps1](modules/windows-repair.ps1), [modules/support-report.ps1](modules/support-report.ps1).
  * **Toolkit Corporativo v0.2 (Fase Alfa)**: [modules/outlook.ps1](modules/outlook.ps1), [modules/teams.ps1](modules/teams.ps1), [modules/browser.ps1](modules/browser.ps1), [modules/programs.ps1](modules/programs.ps1), [modules/services.ps1](modules/services.ps1), [modules/software-install.ps1](modules/software-install.ps1).
* [tests/](tests/) — Testes unitarios, loops de simulacao e seguranca sintatica.
  * [tests/test_parser.ps1](tests/test_parser.ps1) — Validador estatico de sintaxe.
  * [tests/test_imports.ps1](tests/test_imports.ps1) — Validador de escopos e carregamento das funcoes publicas.
  * [tests/test_v02_modules.ps1](tests/test_v02_modules.ps1) — Suite de testes de importacao e sintaxe para a Sprint v0.2.
  * [tests/test_loop.ps1](tests/test_loop.ps1) — Simulador de loop interativo para evitar deadlocks de menu.

---

## Padrao de Desenvolvimento Estrito

Para que o script nao sofra com incompatibilidades de codificacao ou falhas criticas de parser em sistemas Windows antigos com codepages locais personalizadas:
1. **ASCII-Only**: Todos os arquivos de modulo sao codificados estritamente em **ASCII puro** (sem caracteres acentuados, emojis, ou aspas curvas do Office).
2. **UTF-8 sem BOM**: No salvamento, garante-se integridade do texto sem marcas especiais de ordem de byte.
3. **Encadeamento Binario**: Chamadas do utilitario `Join-Path` utilizam no maximo dois argumentos simultaneamente por comando, aninhando-as para manter compatibilidade com PowerShell 5.1.
4. **Resiliencia Cross-Platform**: Qualquer funcionalidade nativa do Windows (ex.: CimInstance, Registry, Spooler) possui fallbacks ou mensagens amigaveis de `N/A` em ambientes Unix de forma silenciosa e limpa.

## Como Executar

### Carregar o assistente (Menu Interativo):
```powershell
Powershell -ExecutionPolicy Bypass -File bootstrap/install.ps1
```

### Rodar a suite de testes locais:
```powershell
# Testes v0.1
pwsh -File tests/test_parser.ps1
pwsh -File tests/test_imports.ps1

# Testes v0.2
pwsh -File tests/test_v02_modules.ps1
pwsh -File tests/test_loop.ps1
pwsh -File tests/test_html_report.ps1
pwsh -File tests/test_software_install.ps1
pwsh -File tests/test_winget_catalog.ps1
```
