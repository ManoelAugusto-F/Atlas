# Changelog Atlas

Todas as mudancas relevantes do projeto estao documentadas neste arquivo.

Formato baseado em versoes semanticas `vMAJOR.MINOR.PATCH`.

---

## v0.5.1
- Corrigido typo no diagnostico do Outlook.
- Adicionado indicador Administrador: SIM/NAO no menu principal.
- Corrigida duplicacao de "Recomendacao:" em Reparos Windows.
- Melhorada saida de configuracao de rede com resumo amigavel.
- Ajustado alinhamento visual do menu principal.

## v0.5.0
- Bootstrap por GitHub Releases (`Get-LatestAtlasRelease`, `Download-AtlasRelease`)
- Versao exibida no menu principal via `version.txt` / `Get-AtlasVersion`
- CHANGELOG formal e processo de release documentado

## v0.4.3
- Correcoes da homologacao Windows 11
- Correcao B001: diagnostico Windows sem status `unknown`
- Correcao B002: limpeza de pastas `Atlas_*` antigas no TEMP
- Correcao B003: total de impressoras exibido corretamente
- Correcao B004: nomes legiveis de navegadores em `Get-BrowserProfiles`

## v0.4.2
- Homologacao Windows 11 (parecer: homologado com ressalvas)
- Registro formal em `docs/HOMOLOGACAO_WINDOWS11.md`

## v0.4.1
- Limpeza de logs legados (`Invoke-AtlasLegacyLogCleanup`)
- Remocao de `provisionador.log` e migracao de `winget_*.log` da raiz

## v0.4.0
- Padronizacao de logs em `C:\ProgramData\Atlas\Logs`
- Retencao automatica de 30 arquivos em Sessions e Winget
- `Write-Log` grava apenas no session log

## v0.3.9
- Organizacao de modulos legados em `legacy/modules/`
- Runtime mantido apenas com modulos ativos

## v0.3.8
- Correcao da validacao de sucesso do Winget por log
- Remocao de barra de progresso artificial do Winget

## v0.3.7
- Winget com execucao gerenciada e logs tecnicos

## v0.3.6
- Melhorias visuais em instalacoes e atualizacoes

## v0.3.5
- Menus compactos e centralizados

## v0.3.4
- Diagnostico guiado de Reparos Windows
- Helpers de UI padronizados

## v0.3.3
- Historico operacional integrado aos modulos

## v0.3.2
- Logger operacional em `atlas.log`
- Menu Historico do Atlas

## v0.3.1
- Correcao de IDs Winget do catalogo

## v0.3.0
- Catalogo de softwares expandido

## v0.2.6
- Remocao do modulo de relatorio HTML

## v0.2.5
- Catalogo Winget corrigido e atualizacao com previa

## v0.2.4
- Validacao de catalogo Winget

## v0.2.3
- Catalogo JSON e log de sessao

## v0.2.2
- Relatorio aprimorado e instalacao de programas

## v0.2.1
- Melhorias de usabilidade e relatorio

## v0.2.0
- Toolkit corporativo (Outlook, Teams, Navegadores)

## v0.1.0
- Primeira versao validada no Windows

## v0.1-pre
- Reset de produto e escopo de manutencao Windows

## v0.1
- Baseline modular inicial
