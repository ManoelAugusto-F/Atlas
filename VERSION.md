# Versao Atual: Atlas v0.2.4

---

## Historico de Versoes

### v0.2.4 - Validacao de catalogo Winget e instalacao com progresso visual
- **Instalacao**: saida nativa do winget com barra de progresso (sem --silent nem captura de output)
- **Validacao**: `tests/test_winget_catalog.ps1` + relatorio `reports/winget_catalog_validation_*.html`
- **Catalogo**: Bizagi Modeler removido (ID invalido no winget)
- **Microsoft 365**: orientacao corporativa/escolar via `https://portal.office.com/account`
- **Pre-install**: validacao `winget show` apos confirmacao unica; mensagem clara se pacote inexistente

### v0.2.3 - Catalogo de software organizado, instalacao rapida e log de sessao
- **Log de sessao**: `Start-AtlasSessionLog`, `Write-AtlasSessionLog`, `Stop-AtlasSessionLog` em `logs/sessions/`
- **Instalacao rapida**: uma confirmacao por app; saida terminal simplificada; detalhes no log de sessao
- **Catalogo JSON**: `config/software-catalog.json` com 7 categorias e 40+ programas
- **Especiais**: RSAT via `Install-RsatFullSafe`; Microsoft 365 via `Open-Microsoft365InstallPage`
- **Extras**: `Update-InstalledSoftwareSafe`, `Export-SoftwareInventory`
- **Removido**: pacote recomendado e instalacao em lote nesta sprint

### v0.2.2 - Relatorio aprimorado, manutencao OneDrive/Outlook e instalacao de programas
- **Relatorio HTML profissional**: resumo executivo com cards, problemas encontrados, diagnostico de lentidao, rede, RDP, OneDrive, impressoras, Windows e acoes recomendadas
- **OneDrive**: desinstalacao assistida, limpeza de residuos e link oficial para reinstalar
- **Outlook**: reparo via Painel de Controle, Apps instalados e pagina oficial Microsoft 365
- **Instalacao de programas**: novo modulo `software-install.ps1` com winget (menu opcao 10)
- **Menu principal**: 10 opcoes (Navegadores em [9], Instalacao de programas em [10])
- **Testes**: test_loop, test_html_report e test_software_install atualizados

### v0.2.1 - Melhorias de Usabilidade e Relatorio (Sprint v0.2.1)
- **Menu Principal**: Reorganizado de 10 opções para 9, eliminando "Diagnóstico Rápido" como opção separada
- **Relatório HTML Aprimorado**:
  - Novo título: "Atlas - Relatório de Suporte da Máquina"
  - 5 novas seções analíticas: "Resumo de Problemas Encontrados", "Lentidão e Travamentos", "Rede e RDP", "Inicialização e Encerramento", "Ações Recomendadas"
  - Diagnóstico rápido integrado ao relatório (não mais opção de menu separada)
- **Melhorias de UX**:
  - Descrições adicionadas a todas as opções de menu (Limpeza, Reparos Windows)
  - Aviso detalhado antes de "Limpeza Segura Completa" explicando o escopo (o que será/não será removido)
  - Menu de Impressoras expandido com 2 novas funções: "Instalar Impressora TCP/IP" e "Adicionar Impressora Compartilhada (UNC)"
- **Funções Novas**: Add-TcpIpPrinterSafe, Add-SharedPrinterSafe (com confirmação e tratamento de erros)
- **Testes Atualizados**: test_loop.ps1 e test_html_report.ps1 validam menu de 9 opções e novas seções do relatório

### v0.2.0 - Integração Toolkit Corporativo
- Planejamento e criação dos modulos de automacao corporativos em fase alfa isolada.
- Adicionados os modulos: outlook.ps1, teams.ps1, browser.ps1, programs.ps1 e services.ps1.
- Reorganizacao do menu principal com opcoes de submenu para cada modulo (Limpeza, Rede, OneDrive, Impressoras, Reparos, Outlook, Teams, Navegadores)

### v0.1.0 — 2026-05-31 — Primeira versão validada no Windows
- Primeira release funcional validada com sucesso no Windows PowerShell 5.1 e PowerShell 7.
- Remocao total de caracteres estendidos, sintonizando todo o core do assistente para ASCII puro.
- Importacao limpa de todas as funcoes de suporte, incluindo SFC, DISM e gerador de relatorios.

### v0.1-pre — 2026-05-30 — Reset de produto

- Redefinição de escopo: Atlas passa a ser Assistente de Manutenção Windows
- Criado `docs/PRODUCT_SCOPE.md` com objetivo, público-alvo, restrições e roadmap
- Novo menu principal definido com 7 opções de manutenção do dia a dia
- Módulos planejados: diagnostics, cleanup, network, onedrive, printers, repair, report
- Código funcional existente preservado sem alterações

### v0.1 — 2026-05-29 — Baseline

- Arquitetura modular consolidada com 10 módulos independentes
- 19 funções públicas seguindo padrão Verb-Noun PascalCase
- Menu interativo com 14 opções de diagnóstico e suporte
- Compatibilidade cross-platform (Windows completo / Linux parcial)
- Coleta de bundle de evidências em `reports/Atlas_Evidence_*/`
- Log centralizado em `logs/provisionador.log`
- Testes automatizados via `tests/test_loop.ps1`
