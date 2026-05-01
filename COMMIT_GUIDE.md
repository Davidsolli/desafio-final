# 📝 Guia de Commits - OmniConnect Fitness

**Padrão:** Conventional Commits em Português (sem Co-Author)

---

## 🎯 Format Básico

```
<tipo>(<escopo>): <descrição concisa>

<corpo detalhado (opcional)>

<footer (opcional)>
```

---

## 📌 Estrutura Detalhada

### 1️⃣ **Tipo (Obrigatório)**

| Tipo | Descrição | Exemplo |
|------|-----------|---------|
| **feat** | Nova funcionalidade | `feat(usuarios): adicionar validação de email` |
| **fix** | Correção de bug | `fix(auth): corrigir timeout de token` |
| **docs** | Documentação | `docs(api): atualizar endpoints` |
| **test** | Testes | `test(usuarios): adicionar testes de validação` |
| **chore** | Build, deps, CI/CD | `chore: atualizar dependências` |
| **refactor** | Refatoração (sem mudança de comportamento) | `refactor(user-service): simplificar lógica` |
| **style** | Formatação, sem lógica | `style: corrigir indentação` |
| **perf** | Melhoria de performance | `perf(db): otimizar query users` |

### 2️⃣ **Escopo (Opcional, mas Recomendado)**

Indique qual parte do código é afetada:

```
feat(usuarios): ...         ✅ Escopo específico
fix(auth): ...              ✅ Escopo específico
chore: ...                  ✅ Sem escopo (quando global)
docs: ...                   ✅ Sem escopo (quando geral)
```

**Escopos Válidos no Projeto:**
- `usuarios` - Módulo de usuários
- `auth` - Autenticação/JWT
- `treinos` - Módulo de treinos
- `ai` - Features de IA
- `db` - Banco de dados
- `api` - API REST geral
- `docker` - Configurações Docker
- `tests` - Configuração de testes

### 3️⃣ **Descrição (Obrigatória)**

- ✅ Imperative mood: "adicionar" (não "adicionado" ou "adiciona")
- ✅ Não comece com letra maiúscula
- ✅ Sem ponto (.) no final
- ✅ Máximo 50 caracteres
- ✅ Seja específico e conciso

```
✅ BOM:
feat(usuarios): adicionar validação de email

❌ RUIM:
feat(usuarios): Add validation for user emails with regex pattern checking
feat(usuarios): Adiciona validação.
feat(usuarios): validação de email foi adicionada
```

### 4️⃣ **Corpo (Opcional mas Recomendado para Mudanças Complexas)**

- Use quando a mudança é complexa ou não óbvia
- Separe com linha em branco da descrição
- Explique **por quê**, não **o quê**
- Use bullet points se necessário

```
feat(usuarios): implementar soft delete

- Usuários deletados não são removidos do banco
- Campo is_active marcado como False
- Mantém auditoria e histórico
- Migração criada para usuários existentes
```

### 5️⃣ **Footer (Opcional)**

Use para referenciar issues, breaking changes, ou menções especiais:

```
Closes #123
Related-To: #456
Breaking-Change: Mudança de API que quebra compatibilidade
```

---

## 💡 Exemplos Práticos

### ✅ BONS Commits

```
feat(usuarios): criar endpoint POST /api/v1/users
```

```
fix(auth): corrigir expiração de token JWT
```

```
docs(api): documentar endpoints de usuários
```

```
test(usuarios): adicionar testes de validação de email

- Testa email válido
- Testa email inválido
- Testa email duplicado
```

```
chore: atualizar dependências (FastAPI, SQLAlchemy)
```

```
refactor(user-service): remover código duplicado

- Consolidar validações em método único
- Reduzir 50 linhas
- Sem mudança de comportamento
```

```
perf(db): otimizar query de listagem de usuários

- Adicionar índice em email
- Remover N+1 queries
- Tempo reduzido de 2s para 200ms
```

---

## ❌ RUINS Commits (Evitar!)

```
❌ feat: mudanças
   → Muito vago, qual é a feature?

❌ feat(usuarios): Add new user functionality with validation and error handling
   → Muito longo (>50 chars), detalhes saem no corpo

❌ feat(usuarios): Adicionada validação.
   → Maiúscula, com ponto, imperativo errado

❌ feat(usuarios): mudança
   → Sem detalhes de o quê foi mudado

❌ WIP: trabalho em progresso
   → Nunca comitar WIP na main/develop

❌ merge branch 'feat/usuarios' into main
   → Commits de merge desnecessários (use rebase)
```

---

## 🔄 Fluxo Completo: Do Desenvolvimento ao Commit

### Passo 1: Criar Branch
```bash
git checkout -b feat/usuarios-crud
```

### Passo 2: Trabalhar (Múltiplos Pequenos Commits)
```bash
# Primeiro commit: estrutura base
git add app/models/user.py app/dtos/user_dto.py
git commit -m "feat(usuarios): criar model e DTOs"

# Segundo commit: lógica de negócio
git add app/services/user_service.py
git commit -m "feat(usuarios): implementar service com validações"

# Terceiro commit: API
git add app/routes/user.py app/controllers/user_controller.py
git commit -m "feat(usuarios): criar endpoints CRUD"

# Quarto commit: testes
git add tests/
git commit -m "test(usuarios): adicionar testes de integração"
```

### Passo 3: Revisar Commits
```bash
git log --oneline feat/usuarios-crud
# Result:
# abc1234 test(usuarios): adicionar testes de integração
# abc1233 feat(usuarios): criar endpoints CRUD
# abc1232 feat(usuarios): implementar service com validações
# abc1231 feat(usuarios): criar model e DTOs
```

### Passo 4: Fazer Push (⚠️ CRÍTICO - VER INSTRUÇÕES COMPLETAS)
```bash
# Primeira vez (com -u - OBRIGATÓRIO)
git push -u origin feat/usuarios-crud

# ⚠️ AGUARDE A RESPOSTA COMPLETA DO GITHUB
# Você deve ver algo como:
# * [new branch] feat/usuarios-crud -> feat/usuarios-crud

# Próximas vezes
git push
```

**⚠️ SE O PUSH NÃO FOR RECONHECIDO:**
```bash
# 1. Verifique se a branch está no remoto:
git branch -vv

# 2. Se não aparecer [origin/...], faça push explícito:
git push origin feat/usuarios-crud --verbose

# 3. Aguarde até ver:
# * [new branch] feat/usuarios-crud -> feat/usuarios-crud
# updating local tracking ref 'refs/remotes/origin/feat/usuarios-crud'
```

### Passo 5: Criar PR no GitHub (CONTRA `develop`)

**⚠️ IMPORTANTE: Só crie o PR DEPOIS de confirmar que o push foi sincronizado!**

```bash
# 1. Verifique que está no remoto:
git branch -vv
# Deve aparecer: feat/usuarios-crud [origin/feat/usuarios-crud] ...

# 2. Crie o PR (SEMPRE com --base develop):
gh pr create --title "feat(usuarios): implementar CRUD de usuários" \
  --base develop \
  --body "Implementa endpoints CRUD completos com validações e testes"
```

**Alternativa via Web (se GitHub CLI falhar):**
```
1. Acesse: https://github.com/seu-repo/pulls
2. Clique "New Pull Request"
3. Selecione: develop ← feat/usuarios-crud
4. Preencha título e descrição
5. Clique "Create Pull Request"
```

---

## 🛠️ Comandos Úteis para Commits

### Ver Histórico Bonitinho
```bash
# Com uma linha por commit
git log --oneline

# Com mais detalhes
git log --format="%h - %s (%an, %ar)"

# Gráfico de branches
git log --oneline --graph --all
```

### Editar Commit Anterior (Se Errou)
```bash
# Mudar mensagem do último commit
git commit --amend -m "feat(usuarios): nova mensagem"

# Adicionar arquivo esquecido
git add arquivo-esquecido.py
git commit --amend --no-edit  # Usa mesma mensagem

# ⚠️ NÃO FAÇA ISSO com commits já pusheados!
# Se já fez push, crie um novo commit em vez de amend
```

### Desfazer Ultimo Commit (Antes de Push)
```bash
# Manter arquivos modificados
git reset --soft HEAD~1

# Descartar tudo
git reset --hard HEAD~1
```

### Squash de Commits (Combinar em Um)
```bash
# Combinar últimos 3 commits em 1
git rebase -i HEAD~3
# Mude as duas primeiras linhas de "pick" para "squash"
# Salve e confirme

# Depois faça push forçado (apenas se não foi pusheado ainda!)
git push --force-with-lease
```

### Ver Diffs Antes de Commitar
```bash
# Ver o que vai ser commitado
git diff --staged

# Ver tudo (staged + unstaged)
git diff HEAD
```

---

## 🚨 Checklist Antes de Fazer Commit

- [ ] Estou em uma branch específica (não main, não develop)
- [ ] Branch segue padrão: `feat/`, `fix/`, `docs/`, etc
- [ ] Rodei testes localmente e passaram
- [ ] Revisei o código antes de commitar
- [ ] Mensagem segue padrão: `<tipo>(<escopo>): <descrição>`
- [ ] Descrição é imperial: "adicionar", não "adicionado"
- [ ] Descrição tem max 50 caracteres
- [ ] Sem Co-Author na mensagem (removido automaticamente)
- [ ] Não há secrets ou .env na mudança
- [ ] Commitei apenas o relevante (não arquivos temporários)

## 🚨 Checklist APÓS Fazer Commit (Antes de Criar PR)

- [ ] Fiz push com: `git push -u origin feat/...` (com -u)
- [ ] Aguardei mensagem: `[new branch] feat/... -> feat/...`
- [ ] Verifiquei com: `git branch -vv`
- [ ] Aparece: `[origin/feat/...]` na minha branch
- [ ] Se não aparecer, fiz: `git push origin feat/... --verbose` novamente
- [ ] Só depois criei PR com: `gh pr create --base develop`

---

## 🔗 Relação: Branches → Commits → PRs

```
┌─ Branch: feat/usuarios-crud
│
├─ Commit 1: feat(usuarios): criar model e DTOs
├─ Commit 2: feat(usuarios): implementar service
├─ Commit 3: feat(usuarios): criar endpoints
└─ Commit 4: test(usuarios): adicionar testes
   │
   └─ PR Title: "feat(usuarios): implementar CRUD de usuários"
      └─ Base: develop (NÃO main!)
         └─ Body: "Implementa endpoints CRUD completos..."
            └─ Merge em develop ✅
               └─ Depois: develop → main (release)
```

---

## 📊 Exemplos Reais do Projeto

### Exemplo 1: Implementação de Feature
```bash
# Commit 1: Model
feat(usuarios): criar model User com UUID e email único

# Commit 2: DTOs
feat(usuarios): adicionar DTOs com validações Pydantic

# Commit 3: Service
feat(usuarios): implementar service com hash bcrypt

# Commit 4: Repository
feat(usuarios): criar repository com ORM queries

# Commit 5: Controller
feat(usuarios): implementar controller

# Commit 6: Routes
feat(usuarios): registrar endpoints HTTP

# Commit 7: Testes
test(usuarios): adicionar 72 testes (cobertura 83%)

# PR: feat(usuarios): implementar CRUD de usuários
```

### Exemplo 2: Correção de Bug
```bash
# Análise
fix(auth): corrigir validação de email

Descrição do bug:
- Regex aceitava emails inválidos
- Causava erro ao salvar no banco
- Solução: usar validador do Pydantic

Closes #42
```

### Exemplo 3: Documentação
```bash
docs(backend): atualizar README com setup Docker

- Adicionar instruções de pré-requisitos
- Explicar fluxo de desenvolvimento
- Adicionar troubleshooting comum
```

---

## ⚡ Dicas Profissionais

### 1️⃣ **Atomic Commits** (Um commit = Uma ideia)
```
✅ Bom: 3 commits pequenos e focados
  - feat: adicionar validação
  - feat: adicionar testes
  - docs: documentar

❌ Ruim: 1 commit gigante com 10 coisas
```

### 2️⃣ **Mensagens Claras** (Futuro você vai agradecer)
```
❌ Ruim: git log mostra "fix bug" (qual bug?)
✅ Bom: git log mostra "fix(auth): corrigir timeout de JWT"
```

### 3️⃣ **Rebase em vez de Merge** (Histórico limpo)
```bash
# Em vez de fazer merge
git merge main  ❌

# Faça rebase
git rebase main  ✅
git push --force-with-lease  # Apenas em branches não mergeadas
```

### 4️⃣ **Nunca Commitar Secrets**
```bash
# Se fez isso por acidente:
git rm --cached .env
git commit -m "chore: remover .env do histórico"

# Mas o arquivo ainda está no histórico!
# Use: git-filter-branch ou BFG (tarefa especial)
```

---

## 📚 Referências

- **Conventional Commits:** https://www.conventionalcommits.org/pt-br/
- **Git Best Practices:** https://git-scm.com/book/en/v2
- **Our Project:** [`BRANCH_STRATEGY.md`](./BRANCH_STRATEGY.md)

---

## 🎓 Resumo (Copiar-Colar Rápido)

```bash
# Branch
git checkout -b feat/seu-recurso

# Trabalhar
nano arquivo.py
git add arquivo.py

# Commit (padrão!)
git commit -m "feat(modulo): sua mensagem concisa"

# Push (com -u - OBRIGATÓRIO)
git push -u origin feat/seu-recurso

# ⚠️ AGUARDE A RESPOSTA COMPLETA, depois verifique:
git branch -vv
# Deve aparecer: [origin/feat/seu-recurso] na sua branch

# Se não aparecer [origin/...], faça push novamente:
git push origin feat/seu-recurso --verbose

# PR (SEMPRE contra develop!)
gh pr create --title "feat(modulo): seu título" --base develop
```

**⚠️ PROBLEMA COMUM:**
```
Se você rodar gh pr create logo após git push -u
e receber erro "Head sha can't be blank", é porque:
1. O GitHub ainda não sincronizou a branch
2. Verifique: git branch -vv
3. O console do GitHub CLI pode estar desatualizado
4. Aguarde 5-10 segundos e tente novamente
5. Ou use a web: https://github.com/seu-repo/pulls
```

---

*Criado para: OmniConnect Fitness - Alpha EdTech*  
*Padrão: Conventional Commits em Português*  
*Sem Co-Author (removido via settings.json)*
