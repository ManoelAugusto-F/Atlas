# Atlas

Ferramenta de manutenção, suporte e automação para ambientes Windows.

O Atlas foi criado para centralizar tarefas comuns de suporte técnico, infraestrutura e administração de estações Windows em uma única interface simples e prática.

Seu objetivo é reduzir o tempo gasto com atividades repetitivas, facilitar correções comuns e padronizar procedimentos executados diariamente por equipes de TI.

**Versão Atual:** v0.3.3

---

## Execução

O Atlas pode ser executado diretamente pela internet, sem necessidade de instalação manual.

### PowerShell

```powershell
irm https://a.bitsdeconhecimento.blog.br/i.ps1 | iex
```

---

## Principais Funcionalidades

### Limpeza e Otimização

- Limpeza de arquivos temporários
- Limpeza de cache DNS
- Limpeza de cache do Windows Update
- Limpeza de lixeira
- Identificação de arquivos e pastas com grande consumo de espaço

### Rede e Conectividade

- Diagnóstico de conectividade
- Renovação de endereço IP
- Reset Winsock
- Reset TCP/IP
- Diagnóstico DNS

### Microsoft 365

- OneDrive
- Outlook
- Teams
- Microsoft 365 Apps

### Impressoras

- Reinício do serviço de impressão
- Limpeza de filas de impressão
- Diagnóstico básico
- Correções comuns

### Reparos do Windows

- SFC
- DISM
- Reset do Windows Update
- Verificações de integridade do sistema

### Instalação de Softwares

Catálogo integrado com instalação e atualização via Winget.

Inclui aplicações utilizadas em:

- Suporte Técnico
- Infraestrutura
- Redes
- Desenvolvimento
- Banco de Dados
- Produtividade

---

## Histórico Operacional

Todas as ações executadas pelo Atlas são registradas automaticamente.

Localização:

```text
C:\ProgramData\Atlas\Logs\atlas.log
```

Informações registradas:

- Data e hora
- Usuário
- Computador
- Módulo executado
- Ação realizada
- Resultado da operação

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
- Draw.io
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
- OpenVPN
- Wireshark
- Nmap
- Remote Desktop Manager
- WinBox
- RSAT

### Banco de Dados

- SQL Server Management Studio
- DBeaver Community

### Microsoft

- Microsoft 365 Apps
- Teams
- OneDrive
- PowerToys
- Windows Terminal
- Power BI Desktop
- Remote Desktop

### Utilitários

- 7-Zip
- Everything
- ShareX
- Greenshot

---

## Segurança

- Utiliza recursos nativos do Windows
- Utiliza o Winget para gerenciamento de softwares
- Não utiliza ativadores ou ferramentas não oficiais
- Operações críticas exigem confirmação do usuário
- Mantém histórico das ações executadas

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

## Projeto

O Atlas é um projeto pessoal focado em automação, suporte e infraestrutura Windows, desenvolvido para simplificar atividades recorrentes do dia a dia de profissionais de TI.