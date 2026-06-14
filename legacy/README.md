# Modulos Legados do Atlas

Este diretorio preserva modulos antigos do Atlas que **nao fazem parte do runtime atual**.

## Por que existem aqui

- Mantidos por **historico tecnico** e referencia de auditoria.
- **Nao sao carregados** pelo `bootstrap/install.ps1`.
- **Nao aparecem** no menu principal nem em fluxos ativos.
- Podem ser removidos definitivamente em uma versao futura, apos revisao.

## O que foi movido para `legacy/modules/`

| Arquivo | Observacao |
|---------|------------|
| `health.ps1` | Diagnostico de saude antigo |
| `diagnostics.ps1` | Diagnostico rapido legado |
| `inventory.ps1` | Inventario de hardware/software antigo |
| `evidence.ps1` | Coleta de evidencias para suporte |
| `disk.ps1` | Analise de disco legada |
| `network.ps1` | Rede legada (substituido por `network-tools.ps1`) |
| `system.ps1` | Utilitarios de sistema antigos |
| `windows-health.ps1` | Saude Windows legada |
| `corporate-network.ps1` | Rede corporativa legada |
| `triage.ps1` | Triagem rapida legada |
| `report.ps1` | Relatorio de suporte legado |
| `process.ps1` | Analise de processos legada |
| `events.ps1` | Eventos do sistema legados |
| `security.ps1` | Seguranca legada |
| `maintenance.ps1` | Manutencao legada (substituido por `cleanup.ps1`) |
| `config.ps1` | Configuracao legada |

## Modulos ativos (permanecem em `modules/`)

- `logger.ps1`, `core.ps1`, `menu.ps1`
- `cleanup.ps1`, `network-tools.ps1`, `onedrive.ps1`, `printer.ps1`
- `windows-repair.ps1`, `outlook.ps1`, `teams.ps1`, `browser.ps1`
- `software-install.ps1`, `history.ps1`

## Carregados sem exposicao no menu

Estes modulos **permanecem em `modules/`** e sao dot-sourced pelo bootstrap, mas **nao possuem entrada no menu principal**:

| Arquivo | Motivo de manter |
|---------|------------------|
| `quick-diagnostic.ps1` | Funcoes usadas em testes (`test_loop.ps1`, `test_imports.ps1`) |
| `programs.ps1` | Funcoes usadas em testes (`test_loop.ps1`, `test_v02_modules.ps1`) |
| `services.ps1` | Funcoes usadas em testes (`test_loop.ps1`, `test_v02_modules.ps1`) |

Nao mover para legacy nesta sprint sem refatorar os testes e definir exposicao no menu.

## Uso

**Nao dot-source** arquivos deste diretorio no bootstrap ou em modulos ativos.
