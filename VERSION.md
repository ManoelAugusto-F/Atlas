# Versão Atual: Atlas v0.2.1

---

## Histórico de Versões

### v0.2.1 - Melhorias de Usabilidade e Relatório (Sprint v0.2.1)
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
