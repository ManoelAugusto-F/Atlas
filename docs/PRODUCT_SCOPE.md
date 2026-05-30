# Atlas — Escopo do Produto

**Versão de referência:** v0.1 — Reset de produto  
**Data:** 2026-05-30  
**Status:** Definição inicial

---

## Objetivo

Atlas é um **Assistente de Manutenção Windows** escrito em PowerShell.  
Serve como ferramenta de uso geral para resolver os problemas mais comuns do dia a dia de usuários e técnicos de suporte, sem exigir conhecimento avançado.

A operação é simples: o usuário abre o menu, escolhe o que precisa e o Atlas diagnostica ou corrige o problema de forma segura, com confirmação antes de qualquer ação destrutiva.

---

## Público-alvo

- Técnicos de suporte de nível 1 e 2
- Usuários intermediários que precisam resolver problemas sem chamar TI
- Analistas que precisam gerar evidências rápidas de problemas reportados

---

## Problemas que o Atlas resolve

| Sintoma | Ação do Atlas |
|---------|--------------|
| Computador lento | Diagnóstico de CPU, RAM, processos pesados e tempo de inicialização |
| Disco cheio | Identificar pastas grandes, limpar temporários e cache do Windows Update |
| Internet / DNS com problema | Testes de conectividade, flush de DNS, diagnóstico de adaptadores |
| Temporários acumulados | Limpeza segura de `%TEMP%`, temp do sistema e prefetch |
| Windows Update ocupando espaço | Limpeza do SoftwareDistribution (com confirmação) |
| Lixeira cheia | Esvaziar lixeira com confirmação |
| OneDrive travado | Reiniciar processo do OneDrive e verificar status de sincronização |
| Impressora travada | Reiniciar spooler, limpar fila de impressão |
| Reparos básicos do Windows | Executar SFC e DISM para verificar e reparar arquivos de sistema |

---

## Menu principal

```
Atlas — Assistente de Manutenção Windows

[1] Diagnóstico rápido
[2] Limpeza segura
[3] Rede e internet
[4] OneDrive
[5] Impressoras
[6] Reparos Windows
[7] Relatório de suporte
[0] Sair
```

---

## Módulos planejados

| Opção | Módulo | Responsabilidade |
|-------|--------|-----------------|
| [1] Diagnóstico rápido | `modules/diagnostics.ps1` | CPU, RAM, disco, processos pesados, tempo de boot |
| [2] Limpeza segura | `modules/cleanup.ps1` | Temporários, lixeira, cache Windows Update, prefetch |
| [3] Rede e internet | `modules/network.ps1` | Conectividade, DNS, adaptadores, flush de DNS |
| [4] OneDrive | `modules/onedrive.ps1` | Reiniciar processo, verificar status, limpar cache local |
| [5] Impressoras | `modules/printers.ps1` | Reiniciar spooler, limpar fila, listar impressoras |
| [6] Reparos Windows | `modules/repair.ps1` | SFC /scannow, DISM, verificação de integridade |
| [7] Relatório de suporte | `modules/report.ps1` | Gerar bundle com evidências para enviar ao suporte |
| — | `modules/logger.ps1` | Log centralizado (já existe, será mantido) |
| — | `modules/system.ps1` | Utilitários e informações de sistema (já existe, será mantido) |
| — | `modules/menu.ps1` | Menu interativo (será reescrito para o novo layout) |

---

## O que NÃO será feito (restrições obrigatórias)

| Categoria | Restrição |
|-----------|-----------|
| Instalação de software | Não instalar programas de terceiros ou da Microsoft Store |
| Debloat | Não remover apps nativos do Windows nem fazer otimizações agressivas |
| Registro | Não aplicar tweaks de registro nesta fase |
| Licenciamento | Não tocar em ativação do Windows ou Office |
| Scripts externos | Não utilizar scripts de terceiros ou baixar código da internet |
| Ações sem aviso | Toda ação destrutiva exige confirmação explícita do usuário |
| Interface gráfica | Sem GUI nesta fase; apenas terminal |
| Integração remota | Sem chamadas a URLs externas, APIs ou servidores |
| Automação silenciosa | Toda ação significativa deve ser registrada em log |

---

## Regras de engenharia

1. **Toda função registra log** via `Write-Log` de `modules/logger.ps1`.
2. **Toda função trata erro** com `try/catch` e mensagem amigável ao usuário.
3. **Toda ação destrutiva pede confirmação** (`$confirmation = Read-Host`).
4. **Arquitetura modular**: cada módulo é independente e pode ser testado isoladamente.
5. **Compatibilidade Linux**: funções exclusivas do Windows exibem aviso informativo em vez de lançar exceção — necessário para desenvolvimento e CI.
6. **Sem hardcode de caminhos**: usar variáveis de ambiente (`$env:TEMP`, `$env:SystemRoot`, etc.).

---

## O que será aproveitado da versão anterior

| Artefato | Motivo |
|----------|--------|
| `bootstrap/install.ps1` | Ponto de entrada principal, será adaptado para o novo menu |
| `modules/logger.ps1` | Sistema de log já consolidado e funcional |
| `modules/system.ps1` | Utilitários de sistema reaproveitáveis |
| `modules/network.ps1` | Base de diagnóstico de rede aproveitável |
| `modules/report.ps1` | Base para geração de relatório de suporte |
| `logs/` | Estrutura de logs mantida |
| `reports/` | Estrutura de relatórios mantida |
| `tests/` | Infraestrutura de testes mantida |
| Git history | Histórico de desenvolvimento preservado |

---

## Roadmap de fases

| Fase | Entregável |
|------|-----------|
| **Fase 0 (atual)** | Reset de escopo, documentação, sem alteração de código |
| **Fase 1** | Novo menu principal + módulos de diagnóstico e limpeza |
| **Fase 2** | Módulos de rede, OneDrive e impressoras |
| **Fase 3** | Módulos de reparo Windows e relatório de suporte |
| **Fase 4** | Testes automatizados completos e documentação de uso |
