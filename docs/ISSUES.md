# Registro de Demandas do Projeto - Issues do Atlas v0.2

Abaixo estao listadas as especifacoes de controle de atividades para o conjunto de ferramentas em desenvolvimento da Sprint **Atlas v0.2**:

## [x] Outlook Toolkit
* **Identificador**: `ISSUE-021`
* **Status**: `COMPLETED`
* **Modulo Alvo**: `modules/outlook.ps1`
* **Requisitos**:
  * Consultar instalacao e processos locais.
  * Reiniciar processos de forma assistida com confirmacao previa.
  * Localizar diretórios de dados locais (OST/PST).

---

## [x] Teams Toolkit
* **Identificador**: `ISSUE-022`
* **Status**: `COMPLETED`
* **Modulo Alvo**: `modules/teams.ps1`
* **Requisitos**:
  * Detetar executavel e instanciamento de processos ativos.
  * Limpar dados temporarios e cache unificados dos diretorios locais do Teams.

---

## [x] Browser Toolkit
* **Identificador**: `ISSUE-023`
* **Status**: `COMPLETED`
* **Modulo Alvo**: `modules/browser.ps1`
* **Requisitos**:
  * Verificar instalacao e perfis do Google Chrome, Microsoft Edge e Mozilla Firefox.
  * Reiniciar processos e limpar pastas de cache do usuario.

---

## [x] Installed Programs Toolkit
* **Identificador**: `ISSUE-024`
* **Status**: `COMPLETED`
* **Modulo Alvo**: `modules/programs.ps1`
* **Requisitos**:
  * Mapear chaves de registro `Uninstall` de 32-bit e 64-bit (User e LocalMachine).
  * Consolidar lista de programas e exportar para arquivo de planilha `reports/programs.csv`.

---

## [x] Services Toolkit
* **Identificador**: `ISSUE-025`
* **Status**: `COMPLETED`
* **Modulo Alvo**: `modules/services.ps1`
* **Requisitos**:
  * Fornecer saude de servicos de redes e servicos corporativos essenciais (como DHCP, Gpsvc, Spooler).
  * Exibir servicos que possuem inicio automatico (`Automatic`), mas que estao indevidamente parados.
  * Implementar reinicializador unificado e seguro.
