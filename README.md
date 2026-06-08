# Atlas

Ferramenta de manutenção, suporte e automação para ambientes Windows.

O Atlas foi criado para centralizar tarefas comuns executadas diariamente por equipes de suporte, infraestrutura e administração de ambientes Microsoft. A proposta é simples: reduzir o tempo gasto com atividades repetitivas, facilitar correções recorrentes e disponibilizar ferramentas úteis em uma única interface.

---

## Execução

O Atlas pode ser executado diretamente pela internet sem necessidade de instalação manual.

Abra o **Windows PowerShell 5.1** ou **PowerShell 7+** como administrador e execute:

```powershell
irm https://a.bitsdeconhecimento.blog.br/i.ps1 | iex
```

---

## O que o Atlas faz?

### Limpeza e Otimização

- Limpeza de arquivos temporários
- Limpeza de cache DNS
- Limpeza de cache do Windows Update
- Limpeza da lixeira
- Identificação de pastas com grande consumo de espaço

### Rede e Conectividade

- Diagnóstico de conectividade
- Renovação de endereço IP
- Reset Winsock
- Reset TCP/IP
- Diagnóstico DNS

### OneDrive

- Verificação de status
- Reinicialização
- Reset completo
- Remoção de resíduos
- Reinstalação

### Outlook

- Diagnóstico
- Verificação da instalação
- Reparo do Microsoft 365
- Acesso rápido às ferramentas de correção

### Teams

- Limpeza de cache
- Correções comuns
- Remoção do Teams pessoal
- Verificação do Teams corporativo

### Impressoras

- Reinício do Spooler
- Limpeza de filas de impressão
- Diagnóstico básico
- Correções comuns

### Reparos do Windows

- **Diagnóstico guiado** — analisa o sistema e recomenda a próxima ação
- Verificar e corrigir arquivos do Windows (SFC)
- Verificar e reparar imagem do Windows (DISM)
- Reset Windows Update

### Interface aprimorada

- Menus compactos e centralizados para leitura rapida no PowerShell
- Reparos Windows com orientacao guiada e descricoes curtas por opcao
- Cores discretas: titulo em Cyan, numeros em Yellow, opcoes em White

### Navegadores

- Google Chrome
- Microsoft Edge
- Mozilla Firefox

Ferramentas de limpeza e correções básicas.

### Instalação e Atualização de Softwares

Catálogo integrado utilizando Winget para instalação e atualização de aplicações.

---

## Histórico Operacional

O Atlas registra automaticamente as ações executadas.

Localização:

```text
C:\ProgramData\Atlas\Logs\atlas.log
```

Cada registro contém:

- Data e hora
- Usuário
- Computador
- Módulo executado
- Ação realizada
- Resultado da operação

Exemplo:

```text
2026-06-07 18:42:11 | INFO | Instalacao | Google Chrome | Sucesso
2026-06-07 18:44:01 | INFO | Rede | Reset Winsock | Sucesso
2026-06-07 18:46:20 | ERROR | OneDrive | Reset | Falha
```

O histórico pode ser consultado diretamente pelo menu do Atlas.

---

## Catálogo de Software

### Navegadores

- Google Chrome
- Microsoft Edge
- Mozilla Firefox
- Brave

### PDF e Documentos

- Adobe Acrobat Reader
- PDF24 Creator
- Foxit PDF Reader
- LibreOffice
- Draw.io Desktop
- Evernote
- Notion

### Desenvolvimento

- Visual Studio Code
- Git
- PowerShell 7
- Notepad++
- Docker Desktop
- WSL
- XAMPP
- WampServer
- PhpStorm
- CodeLite
- Cursor

### Infraestrutura e Redes

- PuTTY
- WinSCP
- MobaXterm
- OpenVPN Community
- OpenVPN Connect
- Wireshark
- Nmap
- Remote Desktop Manager
- WinBox
- RSAT

### Banco de Dados

- SQL Server Management Studio
- SQL Server Management Studio 21
- SQL Server Management Studio 22
- DBeaver Community

### Microsoft

- Microsoft 365 Apps
- Microsoft Teams
- Microsoft OneDrive
- Microsoft PowerToys
- Windows Terminal
- Power BI Desktop
- Microsoft Remote Desktop

### Utilitários

- 7-Zip
- Everything
- ShareX
- Greenshot

---

## Segurança

- Utiliza recursos nativos do Windows
- Utiliza Winget para instalação e atualização de softwares
- Não utiliza ativadores ou ferramentas não oficiais
- Operações críticas exigem confirmação do usuário
- Mantém histórico operacional das ações executadas

---

## Compatibilidade

### Sistemas Operacionais

- Windows 11

### PowerShell

- Windows PowerShell 5.1
- PowerShell 7+

### Dependências

- Winget

---

## Requisitos Recomendados

- Executar como Administrador
- Conexão com internet para instalação de softwares
- Permissões locais para manutenção do sistema

---

## Código Fonte

GitHub:

https://github.com/ManoelAugusto-F/Atlas

---

## Feedback

O Atlas nasceu para resolver problemas reais do dia a dia de suporte e infraestrutura.

Se você utilizar a ferramenta, sugestões, críticas, ideias de melhoria e feedbacks são sempre bem-vindos através do GitHub ou do LinkedIn.

Toda contribuição ajuda a tornar o projeto mais útil para a comunidade de TI.

---

**Versão Atual:** v0.3.5 — Ajuste visual dos menus