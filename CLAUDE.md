# 🤖 Instruções para Claude Code - OmniConnect Fitness

Bem-vindo! Aqui estão as guias para trabalhar com esse projeto.

---

## 🔄 Fluxo Git Obrigatório (IMPORTANTE!)

### ✅ SEMPRE Seguir Este Padrão

```bash
# 1. NUNCA comita direto na main
# 2. Crie uma branch com este padrão:
git checkout -b feat/sua-feature      # Nova feature
git checkout -b fix/seu-bug            # Bug fix
git checkout -b docs/sua-doc           # Docs
git checkout -b chore/sua-tarefa       # Tarefas

# 3. Trabalhe normalmente
git add .
git commit -m "feat: descrição"        # Use conventional commits

# 4. Faça push APENAS da sua branch
git push -u origin feat/sua-feature

# 5. Crie PR no GitHub (manual ou CLI)
gh pr create --title "feat: sua feature"
```

### ❌ PROIBIDO

- ❌ `git push` na `main` (bloqueado por settings.json)
- ❌ Commits com `Co-Authored-By` (removido automaticamente)
- ❌ Branches sem tipo: `fix-usuarios`, `my-feature` (use `feat/`, `fix/`, etc)

---

## 📋 Padrão de Branches

**Veja: [`BRANCH_STRATEGY.md`](./BRANCH_STRATEGY.md)**

**Resumo:**
- `feat/nome-feature` → Novas features
- `fix/nome-bug` → Correções
- `docs/nome-doc` → Documentação
- `chore/nome-tarefa` → Build, deps, etc

---

## 🎯 Padrão de Commits

**Use Conventional Commits em Português:**

```
feat: implementar CRUD de usuários
fix: corrigir validação de email
docs: atualizar README
chore: adicionar bcrypt ao requirements
```

**Sem Co-Author** (removido via settings.json)

---

## 📁 Arquitetura do Projeto

**Veja: [`backend/README.md`](./backend/README.md)**

```
backend/app/
├── routes/       → Endpoints HTTP
├── controllers/  → Orquestração
├── services/     → Lógica de negócio
├── repositories/ → Acesso ao banco
├── models/       → SQLAlchemy ORM
├── dtos/         → Validação (Pydantic)
└── config/       → Configurações
```

---

## 🚀 Como Começar Uma Nova Feature

```bash
# 1. Ler PRD (vê em docs/PRD_*.md)
cat docs/PRD_USUARIOS.md

# 2. Criar branch
git checkout -b feat/sua-feature

# 3. Implementar
# (estará automática padronizado pela estrutura)

# 4. Testes
docker compose up
pytest tests/

# 5. Commit + Push
git add .
git commit -m "feat: sua feature"
git push -u origin feat/sua-feature

# 6. Criar PR
gh pr create --title "feat: sua feature"
```

---

## 📊 Stack & Dependências

- **Backend:** FastAPI + SQLAlchemy + PostgreSQL
- **BD:** PostgreSQL + pgvector (para IA)
- **Security:** bcrypt, JWT
- **Testes:** pytest + pytest-asyncio
- **IA:** LangChain (futuro)

**Docker:** Tudo roda em containers!

---

## 🧪 Testes

```bash
# Rodar tudo
docker compose up
docker exec omniconnect-api pytest -v

# Com cobertura
docker exec omniconnect-api pytest --cov=app --cov-report=html

# Teste específico
docker exec omniconnect-api pytest tests/test_users.py -v
```

---

## 📚 PRDs e Especificações

Todos os PRDs ficam em `docs/`:

- [`docs/PRD_USUARIOS.md`](./docs/PRD_USUARIOS.md) → Gerenciamento de Usuários (✅ PRONTO)

**Próximos PRDs:**
- Autenticação (Login com JWT)
- Treinos (CRUD)
- IA & Recomendações
- Notificações WhatsApp

---

## ⚙️ Configurações

- **`.claude/settings.json`** → Padrões globais (sem Co-Author, protege main)
- **`BRANCH_STRATEGY.md`** → Estratégia de branches
- **`backend/README.md`** → Setup do backend
- **`backend/.env`** → Variáveis de ambiente

---

## 🤖 Usar Claude Agents (Recomendado!)

Pra implementar features rápido, use agents:

```
Claude, implemente o PRD em docs/PRD_USUARIOS.md

Requisitos:
- FastAPI + SQLAlchemy + PostgreSQL
- Arquitetura em camadas (routes, controllers, services, repositories, dtos, models)
- Testes com pytest (≥80% cobertura)
- Senhas com bcrypt
- Validações com Pydantic
- Sem Co-Author nos commits
- Branch: feat/usuarios-crud (ou similar)

Seguir padrão do projeto.
```

Resultado: Implementação completa em 5 minutos! ⚡

---

## 📞 Contato & Dúvidas

- **Branch incorreta?** Vê `BRANCH_STRATEGY.md`
- **Dúvida sobre arquitetura?** Vê `backend/README.md`
- **Dúvida sobre feature?** Vê o PRD correspondente
- **Testes falhando?** Rode `docker compose down -v && docker compose up --build`

---

**Criado por:** Alpha EdTech - Turma Aurora  
**Projeto:** OmniConnect Fitness  
**Stack:** FastAPI + SQLAlchemy + PostgreSQL
