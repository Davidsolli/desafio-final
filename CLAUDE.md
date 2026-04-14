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

## 📝 Padrão de Commits

**📖 LER COMPLETO em: [`COMMIT_GUIDE.md`](./COMMIT_GUIDE.md)** ← OBRIGATÓRIO!

**Use Conventional Commits em Português:**

```
feat(usuarios): implementar CRUD de usuários
fix(auth): corrigir validação de email
docs(api): atualizar README
chore: adicionar bcrypt ao requirements

Corpo detalhado (opcional):
- Explique POR QUÊ, não O QUÊ
- Use bullet points se necessário
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

## 🤖 Como Pedir pra IA Fazer (IMPORTANTE!)

**Leia PRIMEIRO:** [`IA_WORKFLOW.md`](./IA_WORKFLOW.md) ← OBRIGATÓRIO!

**Exemplo rápido:**
```
Claude, implemente o módulo de treinos conforme PRD em docs/PRD_TREINOS.md

Stack: FastAPI + SQLAlchemy + PostgreSQL
Requisitos:
- 5 endpoints CRUD funcionando
- Validações com Pydantic
- ≥8 testes de integração (≥80% cobertura)
- Sem Co-Author nos commits

Padrão: arquitetura em camadas, async/await, sem hardcodes
Output: código funcional, testes passando, commit feito, branch feat/treinos-crud
```

**Resultado:** Feature completa em 20 minutos! ⚡

---

## 🚀 Como Começar Uma Nova Feature

### Com Claude (Recomendado!) 🤖
```
1. Crie um PRD (30 min)
2. Passe pro Claude com prompt específico (5 min)
3. Claude implementa tudo (10 min)
4. Você revisa e aprova (15 min)
TOTAL: 1 hora ⚡
```

### Manual (Se Precisar)
```bash
# 1. Ler PRD
cat docs/PRD_USUARIOS.md

# 2. Criar branch
git checkout -b feat/sua-feature

# 3. Implementar (seguir arquitetura em camadas)
# (estará automática padronizado pela estrutura)

# 4. Testes
docker compose up
pytest tests/ -v --cov

# 5. Commit + Push
git add .
git commit -m "feat(modulo): sua feature"
git push -u origin feat/sua-feature

# 6. Criar PR
gh pr create --title "feat(modulo): sua feature"
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
