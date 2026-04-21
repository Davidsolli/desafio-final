# 🌳 Estratégia de Branches - OmniConnect Fitness

**Padrão:** Git Flow com `develop` como base de desenvolvimento

---

## 📌 Regras Obrigatórias

1. ✅ **NUNCA fazer commit direto na `main` ou `develop`**
2. ✅ **Sempre criar uma branch antes de começar**
3. ✅ **Nome da branch deve seguir o padrão**
4. ✅ **Pull Request obrigatório contra `develop` antes de merge**
5. ✅ **Sem push direto na main/develop** (hook de proteção ativo)
6. ✅ **`main` só recebe merges de `develop` (releases)**

---

## 🏷️ Nomenclatura de Branches (GitHub Flow)

### Formato Base
```
<tipo>/<descrição>
```

### Tipos Válidos

| Tipo | Uso | Exemplo |
|------|-----|---------|
| **feat** | Nova feature/funcionalidade | `feat/usuarios-crud` |
| **fix** | Correção de bug | `fix/email-validation` |
| **docs** | Documentação | `docs/readme-update` |
| **chore** | Dependências, build, etc | `chore/update-dependencies` |
| **refactor** | Refatoração de código | `refactor/user-service` |
| **test** | Testes | `test/user-integration` |
| **style** | Formatação, sem lógica | `style/code-formatting` |

### Regras de Nomeação

- ✅ Usar **minúsculas**
- ✅ Separar palavras com **hífen** (`-`)
- ✅ Ser **descritivo e conciso**
- ✅ Máximo **50 caracteres** (incluindo tipo)

### ✅ BONS Exemplos
```
feat/usuarios-crud
feat/auth-jwt
feat/treinos-module
fix/password-validation
docs/api-endpoints
chore/update-dependencies
```

### ❌ RUINS Exemplos
```
feature/usuarios_CRUD          ❌ Mistura tipo com "feature"
feat/users-create-read-update   ❌ Muito longo (>50 chars)
FEAT/USUARIOS                   ❌ Maiúsculas
feat_usuarios                   ❌ Underscore em vez de hífen
wip                             ❌ Sem tipo
```

---

## 🌿 Fluxo de Branches (Git Flow)

```
main (releases)
  ↑
  └─ develop (base de desenvolvimento)
      ↑
      ├─ feat/usuarios-crud
      ├─ fix/email-validation
      ├─ docs/readme-update
      └─ ...outras features
```

**Fluxo de versões:**
```
1. Você cria: feat/usuarios-crud
2. Você faz PR → develop
3. Time revisa e aprova
4. Merge em develop ✅
5. Quando pronto para release: merge develop → main com tag de versão
```

---

## 🔄 Fluxo de Trabalho (Passo a Passo)

### 1️⃣ Começar Nova Feature

```bash
# Crie e acesse a branch
git checkout -b feat/usuarios-crud

# Ou mais curto
git switch -c feat/usuarios-crud
```

### 2️⃣ Trabalhar Normalmente

```bash
# Editar, testar, commitar
git add .
git commit -m "feat: implementar CRUD de usuários"

# Se fizer múltiplos commits, tudo bem
git commit -m "test: adicionar testes de usuários"
```

### 3️⃣ Enviar para Remoto

```bash
# Push da sua branch (primeira vez)
git push -u origin feat/usuarios-crud

# Próximos pushes
git push
```

### 4️⃣ Criar Pull Request (Contra `develop`)

```bash
# GitHub CLI (recomendado) - SEMPRE contra develop!
gh pr create --title "feat: implementar CRUD de usuários" \
  --body "Implementa criação, leitura, atualização e deleção de usuários" \
  --base develop

# Ou via web: https://github.com/seu-repo/pulls
# ⚠️ IMPORTANTE: Mude a base para 'develop' na interface web!
```

### 5️⃣ Merge e Cleanup

```bash
# Depois que PR for aprovada e mergeada em develop:

# Volta pra develop
git checkout develop

# Atualiza local
git pull

# Deleta a branch local
git branch -d feat/usuarios-crud

# Deleta do remoto (automático se usar GitHub web)
git push origin --delete feat/usuarios-crud
```

---

## 🚫 Proteções Ativadas

### Hooks Locais
- ❌ Impede `git push` na main
- ❌ Impede `git push` na develop
- ❌ Valida nomenclatura de branch
- ✅ Permite força com flag especial (admin only)

### Regras GitHub
- ❌ Proíbe push direto na main
- ❌ Proíbe push direto na develop
- ✅ PRs obrigatórios CONTRA `develop`
- ✅ Requer 1+ reviewers
- ✅ Requer testes passando
- ✅ `main` só recebe merges de `develop` (releases)

---

## 📝 Conventional Commits (Combina com Branches)

Seus commits devem seguir o padrão:

```
feat(modulo): descrição curta

Descrição detalhada...
```

**Relação Branch → Commit:**
```
Branch: feat/usuarios-crud
Commit: feat(usuarios): implementar CRUD de usuários
```

---

## 🎯 Checklist Antes de Fazer Push

- [ ] Estou em uma branch (não em `main` ou `develop`)
- [ ] Nome segue padrão: `feat/`, `fix/`, `docs/`, etc
- [ ] Comittei com conventional commits
- [ ] Rodei testes localmente
- [ ] Código segue padrão do projeto
- [ ] Sem `Co-Authored-By` (removido em settings.json)
- [ ] PR será criado CONTRA `develop` (não main)

---

## 🔧 Comandos Úteis

```bash
# Ver branches locais
git branch

# Ver todas as branches
git branch -a

# Renomear branch (se errou o nome)
git branch -m feat/usuario-errado feat/usuario-correto

# Ver histórico de branches deletadas
git reflog

# Criar branch a partir de commit anterior
git checkout -b feat/nova-branch abc123def

# Atualizar sua branch com changes da main
git fetch origin
git rebase origin/main
```

---

## ⚠️ Se Você Fez Commit na Main (Erro!)

```bash
# 1. Crie a branch correta
git checkout -b feat/usuarios-crud

# 2. Volta pra main
git checkout main

# 3. Reseta main pro estado anterior
git reset --hard origin/main

# 4. Volte pra sua branch (o commit está lá!)
git checkout feat/usuarios-crud
```

---

*Criado para: OmniConnect Fitness - Alpha EdTech*  
*Padrão: GitHub Flow com Conventional Commits*
