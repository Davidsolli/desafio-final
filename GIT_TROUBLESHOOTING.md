# 🔧 Git Troubleshooting - OmniConnect Fitness

Soluções rápidas para problemas comuns ao fazer push e criar PRs.

---

## 🚨 Problema: "Head sha can't be blank" ao criar PR

**Sintoma:**
```
Error: GraphQL: Head sha can't be blank, Base sha can't be blank
```

**Causa:**
- Você rodou `gh pr create` muito rápido após `git push -u`
- O GitHub ainda não sincronizou a branch
- GitHub CLI e repositório local estão desincronizados

**Solução:**

```bash
# 1. Verifique se a branch está no remoto
git branch -vv

# ✅ CORRETO (aparece [origin/...]):
# * feat/usuarios-crud  abc1234 [origin/feat/usuarios-crud] feat:...

# ❌ ERRADO (não aparece [origin/...]):
# * feat/usuarios-crud  abc1234 feat:...

# 2. Se não aparecer [origin/...], o push não sincronizou
# Faça push novamente (com --verbose para ver o progresso):
git push origin feat/usuarios-crud --verbose

# 3. Aguarde a mensagem:
# updating local tracking ref 'refs/remotes/origin/feat/usuarios-crud'

# 4. Verifique novamente:
git branch -vv
# Agora deve aparecer: [origin/feat/usuarios-crud]

# 5. Só depois crie o PR:
gh pr create --title "feat: sua feature" --base develop
```

---

## 🚨 Problema: PR não aparece no GitHub

**Sintoma:**
- Criei o PR, mas não aparece na página de PRs do GitHub
- `gh pr view` retorna erro

**Causa:**
- A branch não foi reconhecida pelo GitHub
- PR foi criado na conta errada (se tiver múltiplas contas)
- Problema de autenticação

**Solução:**

```bash
# 1. Confirme que está logado no GitHub:
gh auth status
# Deve aparecer qual conta você está usando

# 2. Se estiver logado em conta errada, faça logout:
gh auth logout

# 3. Faça login novamente:
gh auth login
# Escolha: GitHub.com
# Escolha: HTTPS
# Escolha: Authenticate with your GitHub credentials

# 4. Verifique branches no remoto:
git branch -r
# Deve aparecer: origin/feat/usuarios-crud

# 5. Se não aparecer, faça push com --all:
git push -u origin feat/usuarios-crud

# 6. Tente criar PR novamente:
gh pr create --title "feat: sua feature" --base develop
```

---

## 🚨 Problema: "You must first push the current branch to a remote"

**Sintoma:**
```
aborted: you must first push the current branch to a remote, or use the --head flag
```

**Causa:**
- Você tentou criar PR sem fazer push antes
- Branch local não foi enviada para o GitHub

**Solução:**

```bash
# 1. Faça o push com -u:
git push -u origin feat/usuarios-crud

# 2. Aguarde (5-10 segundos)

# 3. Verifique:
git branch -vv
# Deve aparecer: [origin/feat/usuarios-crud]

# 4. Só depois crie o PR:
gh pr create --title "feat: sua feature" --base develop
```

---

## 🚨 Problema: "No commits between develop and feat/usuarios"

**Sintoma:**
```
Error: GraphQL: No commits between develop and feat/usuarios-crud
```

**Causa:**
- Você criou a branch mas fez commits de outras branches
- A branch atual não tem commits novos
- Problema de sincronização

**Solução:**

```bash
# 1. Verifique em qual branch está:
git branch

# 2. Verifique o histórico de commits:
git log --oneline -5
# Deve aparecer seus commits novos

# 3. Se não aparecer, seus commits estão em outra branch
# Primeiro, liste todos os commits:
git log --oneline --all | head -10

# 4. Se necessário, mude de branch:
git checkout feat/usuarios-crud

# 5. Faça push:
git push -u origin feat/usuarios-crud

# 6. Aguarde sincronização
git branch -vv

# 7. Crie o PR:
gh pr create --title "feat: sua feature" --base develop
```

---

## 🚨 Problema: "Branch 'feat/usuarios' doesn't exist"

**Sintoma:**
```
Error: branch 'feat/usuarios-crud' doesn't exist
```

**Causa:**
- Você deletou a branch local
- Digitou o nome errado
- Está em outra branch

**Solução:**

```bash
# 1. Veja todas as branches:
git branch -a

# 2. Se a branch local foi deletada, restaure:
git checkout -b feat/usuarios-crud origin/feat/usuarios-crud

# 3. Se digitou errado, crie a correta:
git checkout -b feat/usuarios-crud

# 4. Verifique em qual branch está:
git branch
# O * indica a branch atual
```

---

## 🚨 Problema: Push rejeitado (permissão negada)

**Sintoma:**
```
remote: Permission to user/repo.git denied to another-user
```

**Causa:**
- Você está autenticado com a conta errada
- Não tem permissão no repositório
- SSH key configurada incorretamente

**Solução:**

```bash
# 1. Verifique qual conta está usando:
gh auth status

# 2. Se estiver errado, logout:
gh auth logout

# 3. Login com a conta correta:
gh auth login

# 4. Ou reconfigure SSH (alternativo):
ssh-add ~/.ssh/id_rsa  # ou seu nome de chave

# 5. Teste a conexão:
ssh -T git@github.com

# 6. Tente push novamente:
git push -u origin feat/usuarios-crud
```

---

## ✅ Fluxo Correto (Evite Problemas)

```bash
# 1. Crie branch
git checkout -b feat/seu-recurso

# 2. Trabalhe, commit
git add .
git commit -m "feat(modulo): sua mensagem"

# 3. Push (com -u - OBRIGATÓRIO)
git push -u origin feat/seu-recurso

# 4. ⏱️ AGUARDE 5-10 segundos

# 5. VERIFIQUE se está no remoto
git branch -vv
# Deve mostrar: [origin/feat/seu-recurso]

# 6. Se não aparecer, push novamente
git push origin feat/seu-recurso --verbose
# Aguarde: "updating local tracking ref"

# 7. SÓ DEPOIS crie o PR
gh pr create --title "feat(modulo): seu título" --base develop
```

---

## 🔍 Comandos de Diagnóstico

Quando algo der errado, rode esses comandos para entender o que aconteceu:

```bash
# Ver o status atual
git status

# Ver branches locais vs. remoto
git branch -vv

# Ver histórico de commits
git log --oneline -10

# Ver qual conta GitHub está usando
gh auth status

# Ver todas as branches (local + remoto)
git branch -a

# Ver o URL do remoto
git remote -v

# Testar conexão SSH
ssh -T git@github.com

# Ver últimas operações (se perdeu uma branch)
git reflog
```

---

## 📚 Referências Rápidas

| Erro | Solução |
|------|---------|
| Head sha can't be blank | Aguarde 5-10s após push, depois crie PR |
| No commits between... | Verifique se está na branch correta com `git branch` |
| doesn't exist | Liste branches com `git branch -a` |
| Permission denied | Verifique conta com `gh auth status` |
| must first push | Faça `git push -u origin feat/...` primeiro |

---

## 🎯 Checklist de Sanitização (Se Nada der Certo)

```bash
# 1. Confirme que está na branch correta
git branch
# O * mostra a branch atual

# 2. Confirme que tem commits
git log --oneline -1
# Deve aparecer seu último commit

# 3. Confirme que está no repositório correto
git remote -v
# Deve aparecer o repositório correto

# 4. Limpe os dados de tracking local
git fetch origin
git branch -vv

# 5. Se nada funcionar, comece do zero:
cd ..
rm -rf desafio-final    # ❌ CUIDADO: Remove tudo!
git clone git@github.com:Davidsolli/desafio-final.git
cd desafio-final
git checkout -b feat/seu-recurso
# ... trabalhe normal ...
```

---

*Criado para: OmniConnect Fitness - Alpha EdTech*  
*Atualizado: Para evitar problemas de sincronização GitHub*
