# Processo de Release do Atlas

Este documento descreve como publicar uma nova versao estavel do Atlas via GitHub Releases.

---

## Pre-requisitos

- Acesso de escrita ao repositorio `ManoelAugusto-F/Atlas`
- Git configurado localmente
- GitHub CLI (`gh`) opcional, mas recomendado

---

## Passo a passo

### 1. Atualizar VERSION.md

Edite a primeira linha:

```text
# Versao Atual: Atlas vX.Y.Z
```

Adicione a secao da nova versao no historico.

### 2. Atualizar version.txt

Arquivo na raiz do repositorio com uma unica linha:

```text
vX.Y.Z
```

Este arquivo e lido por `Get-AtlasVersion` e exibido no menu principal.

### 3. Atualizar CHANGELOG.md

Adicione a nova versao em `docs/CHANGELOG.md` com as mudancas relevantes.

### 4. Commit

```powershell
git add VERSION.md version.txt docs/CHANGELOG.md
git commit -m "Prepara release vX.Y.Z"
git push
```

### 5. Criar tag Git

```powershell
git tag vX.Y.Z
git push origin vX.Y.Z
```

### 6. Criar GitHub Release

Via GitHub CLI:

```powershell
gh release create vX.Y.Z `
  --title "Atlas vX.Y.Z" `
  --notes-file docs/CHANGELOG.md
```

Ou manualmente em:

https://github.com/ManoelAugusto-F/Atlas/releases/new

Selecione a tag criada e publique a release.

---

## Bootstrap online

O instalador (`i.ps1`) consulta:

```text
https://api.github.com/repos/ManoelAugusto-F/Atlas/releases/latest
```

E baixa o `zipball_url` da release mais recente.

Se a API falhar, usa fallback:

```text
https://github.com/ManoelAugusto-F/Atlas/archive/refs/heads/main.zip
```

---

## Primeira release oficial v0.5.0

Apos o commit desta sprint:

```powershell
git tag v0.5.0
git push origin v0.5.0
gh release create v0.5.0 --title "Atlas v0.5.0" --notes "Bootstrap por Release e Gestao de Versoes"
```

A partir desta release, o comando:

```powershell
irm https://a.bitsdeconhecimento.blog.br/i.ps1 | iex
```

instalara a versao estavel publicada, nao mais a branch `main` diretamente.

---

## Checklist antes de publicar

- [ ] Testes locais passando (`tests/test_*.ps1`)
- [ ] `VERSION.md` atualizado
- [ ] `version.txt` atualizado
- [ ] `docs/CHANGELOG.md` atualizado
- [ ] Tag Git criada e enviada
- [ ] GitHub Release publicada
- [ ] Validacao manual via bootstrap online
