# Atlas

**Assistente de manutencao e suporte Windows em PowerShell.**

Atlas e uma ferramenta PowerShell para tecnicos de suporte, analistas de infraestrutura e usuarios avancados que precisam executar correcoes e manutencoes comuns no Windows de forma rapida, organizada e segura.

**Status:** MVP v0.2.6

---

## Uso

O fluxo principal do Atlas sera execucao online via PowerShell — sem necessidade de clonar o repositorio ou instalar o projeto manualmente.

```powershell
irm https://sua-url-curta/atlas | iex
```

> A URL acima e um placeholder. O bootstrap online ainda nao esta publicado.

**Como funcionara:**

- O bootstrap online baixara a versao estavel do Atlas a partir das releases do GitHub.
- A execucao sera temporaria — o objetivo e rodar a ferramenta sem instalacao local do projeto.
- O repositorio GitHub permanece como fonte de codigo, versionamento e releases oficiais.
- O usuario final nao precisa de `git clone`, dependencias manuais ou configuracao de ambiente de desenvolvimento.

---

## Funcionalidades

| Modulo | Recursos |
|--------|----------|
| Limpeza segura | Temporarios, lixeira, cache Windows Update |
| Rede e internet | DNS, IP, Winsock, TCP/IP |
| OneDrive | Status, reset, remocao assistida, reinstalacao |
| Impressoras | Spooler, fila, TCP/IP, impressora compartilhada |
| Reparos Windows | SFC, DISM, Windows Update |
| Outlook | Status, cache, reparo Office |
| Teams | Cache, Teams pessoal/corporativo |
| Navegadores | Chrome, Edge, Firefox, cache |
| Instalacao de programas | Catalogo Winget por categorias |

O menu principal oferece 9 acoes operacionais acessiveis por numeracao simples, com confirmacao antes de qualquer acao destrutiva.

---

## Catalogo de software

Programas organizados por categoria em `config/software-catalog.json`, instalados via Winget com confirmacao unica por item:

- Navegadores
- PDF e Documentos
- Desenvolvimento
- Infraestrutura e Redes
- Banco de Dados
- Microsoft
- Utilitarios

Fluxos especiais incluem RSAT e Microsoft 365 Apps, com validacao de pacotes antes da instalacao.

---

## Seguranca operacional

Atlas foi projetado para uso em ambiente corporativo e de suporte tecnico:

- **Confirmacao obrigatoria** antes de acoes destrutivas (limpeza, reset, remocao).
- **Confirmacao obrigatoria** antes de cada instalacao de programa.
- **Sem ativadores** de software ou licencas.
- **Sem scripts de terceiros** — apenas modulos proprios do Atlas.
- **Recursos nativos do Windows** (SFC, DISM, WMI, Registry, Spooler) e **Winget** para instalacao.
- **Compativel com Windows PowerShell 5.1** — padrao em estacoes corporativas.

Cada sessao gera log persistente em `logs/sessions/` para auditoria e rastreabilidade.

---

## Compatibilidade

| Requisito | Suporte |
|-----------|---------|
| Windows 10 | Sim |
| Windows 11 | Sim |
| Windows PowerShell 5.1 | Sim (recomendado) |
| PowerShell 7+ | Sim |
| Winget | Necessario para instalacao de programas |

Funcionalidades nativas do Windows retornam mensagens informativas em ambientes nao-Windows (util para desenvolvimento e testes).

---

## Roadmap

| Versao | Entrega |
|--------|---------|
| **v0.2.6** | MVP estavel — manutencao, correcao e suporte operacional |
| **v0.3** | Bootstrap online via `irm \| iex` |
| **v0.4** | Execucao temporaria com limpeza automatica |
| **v0.5** | Pagina publica e documentacao para usuario final |
| **Futuro** | Interface grafica |

Detalhes tecnicos em [docs/ROADMAP.md](docs/ROADMAP.md).

---

## Estrutura do projeto

```
bootstrap/     # Bootstrap e menu principal
modules/       # Modulos de manutencao e toolkit corporativo
config/        # Catalogo de software e configuracoes
tests/         # Suite de testes automatizados
docs/          # Arquitetura, escopo, roadmap e releases
logs/          # Logs de sessao e operacao
```

Documentacao complementar: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [docs/PRODUCT_SCOPE.md](docs/PRODUCT_SCOPE.md)

---

## Desenvolvimento

Esta secao e destinada a contribuidores e mantenedores do projeto — nao ao usuario final.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\tests\test_loop.ps1
powershell.exe -ExecutionPolicy Bypass -File .\tests\test_software_install.ps1
```

Para execucao local durante o desenvolvimento:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\bootstrap\install.ps1
```

---

## Licenca

A definir.
