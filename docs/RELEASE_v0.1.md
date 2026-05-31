# Release Release Atlas v0.1

Este documento descreve os detalhes de governanca, arquitetura e entrega da versao inicial de producao (v0.1) do **Atlas - Assistente de Manutencao Windows**.

## Visao Geral
O Atlas e um assistente interativo modular desenvolvido em PowerShell focado no diagnostico preventivo e corretivo de estacoes de trabalho. Ele visa consolidar ferramentas de suporte comumente dispersas em uma interface unificada, resiliente e segura, garantindo execucao tanto no Windows PowerShell 5.1 tradicional quanto em PowerShell Core 7 (cross-platform).

## Objetivo
Auxiliar analistas de suporte e usuarios finais com tarefas rapidas de triagem como:
* Verificacao de recursos de hardware de baixo nivel (disco, memoria, uptime).
* Analise e reparo de pilha de rede, cache DNS e tabelas de roteamento.
* Diagnostico e gerenciamento de software corporativo integrado (OneDrive, Spooler de impressao).
* Correcao de bugs de sistema via APIs do SFC (System File Checker) e DISM.
* Extracao unificada de relatorios diagnosticos com encapsulamento de logs.

## Funcionalidades Entregues (v0.1)
* **Modulo de Logger (`logger.ps1`)**: Centraliza gravacao de logs com niveis (`INFO`, `WARN`, `ERROR`) salvos em `logs/provisionador.log`.
* **Modulo Core (`core.ps1`)**: Helpers globais de interatividade, confirmacoes e mensagens unificadas.
* **Menu Interativo (`menu.ps1`)**: Exibicao dinamica do console e direcionamento de opcoes.
* **Diagnostico Rapido (`quick-diagnostic.ps1`)**: Verifica em menos de 10 segundos alertas de disco, memoria,uptime, conectividade TCP/DNS google, status OneDrive e Spooler.
* **Limpeza Segura (`cleanup.ps1`)**: Limpa arquivos temporarios do usuario, do cache do Windows Update e lixeira com seguranca.
* **Rede e Internet (`network-tools.ps1`)**: Limpeza de cache DNS, redefinicao de Winsock e adaptadores DHCP.
* **OneDrive Toolkit (`onedrive.ps1`)**: Reinicializacao do app, redefinicao de sincronizacoes `/reset` e atalhos aos logs e pastas.
* **Modulo de Impressoras (`printer.ps1`)**: Lista impressoras, fila pendente de impressao (jobs), drivers locais e limpeza fisica da pasta de Spool (`spool/PRINTERS`).
* **Reparos Windows (`windows-repair.ps1`)**: Oferece rotinas do `sfc /verifyonly`, `sfc /scannow`, `DISM /CheckHealth`, `/ScanHealth`, `/RestoreHealth` e redefinicao de servicos de Windows Update.
* **Relatorio de Suporte (`support-report.ps1`)**: Consolida todas as secoes em arquivos TXT individuais e empacota um resumo JSON legivel em subpasta estruturada dentro de `reports/`.

## Limitacoes Conhecidas
* Algumas funcoes administrativas (SFC, DISM, Limpeza de Spool) requerem explicitamente a elevacao de privilegios (Executar como Administrador) sob o Windows PowerShell 5.1.
* No Linux (PowerShell Core 7), os modulos do OneDrive, Impressoras e Reparos do Windows exibem status `N/A` ou mensagens de aviso apropriadas, ja que dependem de componentes de Kernel e APIs internas do Windows (como CIM e COM).

## Sistemas Testados
* Windows 10 Pro / Enterprise (builds 22H2+)
* Windows 11 Enterprise LTSC
* Windows Server 2022
* Linux Ubuntu 22.04 LTS (utilizando `pwsh`)

## Testes Realizados
* **Testes de Parser**: Testados por meio de simuladores nativos do PowerShell para verificar erros de sintaxe (como aspas inteligentes, parenteses e chaves desbalanceadas).
* **Testes de Importacao**: Script de validacao importou com sucesso todos os arquivos simultaneamente, emitindo `[OK]` para as 17 funcoes publicas principais.
* **Teste de Loop (`test_loop.ps1`)**: Simula entradas do console e loops de selecoes para as opcoes do menu, garantindo nao haver deadlocks ou loops infinitos de entrada.

## Bugs Corrigidos
* **Parser do Windows PowerShell 5.1**: Corrigida a decodificacao de caracteres UTF-8 no analisador nativo do Windows (conversao dos modulos de Unicode estendido para ASCII puro plano).
* **Join-Path com Segmentos Multiplos**: Substituido o encadeamento de mais de dois caminhos por chamadas aninhadas em `support-report.ps1` no padrao compativel com PS 5.1.
* **Nomes de Funcoes Ausentes no Windows Repair**: Corrigido Bug de compatibilidade que bloqueava a exportacao das funcoes `Invoke-SfcScannowSafe` e `Test-DismCheckHealth`.

## Estrutura Atual
```
├── README.md
├── VERSION.md
├── assets/
├── bootstrap/
│   └── install.ps1
├── config/
│   └── apps.json
├── docs/
│   ├── ARCHITECTURE.md
│   ├── PRODUCT_SCOPE.md
│   ├── RELEASE_v0.1.md ------ (Novo)
│   ├── ROADMAP.md ----------- (Novo)
│   └── WINDOWS_TESTS.md ----- (Novo)
├── logs/
├── modules/
│   ├── cleanup.ps1
│   ├── config.ps1
│   ├── core.ps1
│   ├── logger.ps1
│   ├── menu.ps1
│   ├── network-tools.ps1
│   ├── onedrive.ps1
│   ├── printer.ps1
│   ├── quick-diagnostic.ps1
│   ├── support-report.ps1
│   └── windows-repair.ps1
├── reports/
└── tests/
    ├── test_imports.ps1
    ├── test_loop.ps1
    └── test_parser.ps1
```

## Proximos Passos
* Implementacao da nova suite de ferramentas empresariais corporativas para a Sprint v0.2.
* Desenvolvimento inicial dos modulos isolados sem integracao direta ao menu principal nas fases alfa.
