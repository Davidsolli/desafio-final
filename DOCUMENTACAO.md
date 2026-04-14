# 📚 Índice de Documentação - OmniConnect Fitness

Bem-vindo! Aqui está toda a documentação organizada por tópico.

---

## 🎯 Por Onde Começar?

### 👤 **Novo na Equipe?**
1. Leia: [`CLAUDE.md`](./CLAUDE.md) (Visão geral do projeto)
2. Leia: [`BRANCH_STRATEGY.md`](./BRANCH_STRATEGY.md) (Como trabalhar com git)
3. Leia: [`COMMIT_GUIDE.md`](./COMMIT_GUIDE.md) (Como fazer commits)

### 🤖 **Quer Usar IA pra Programar?**
→ Leia: [`IA_WORKFLOW.md`](./IA_WORKFLOW.md) (Como pedir pra Claude fazer)

### 🛠️ **Quer Implementar uma Feature?**
1. Leia o PRD correspondente em [`docs/`](./docs/)
2. Estruture o prompt (veja [`IA_WORKFLOW.md`](./IA_WORKFLOW.md))
3. Dispare pro Claude ou implemente manualmente

### 🚀 **Quer Subir o Backend?**
→ Leia: [`backend/README.md`](./backend/README.md)

---

## 📖 Documentação Completa

### 1. **CLAUDE.md** - Instruções Gerais do Projeto
- Fluxo git obrigatório
- Padrão de branches
- Padrão de commits
- Como começar uma feature
- Stack e dependências
- Testes
- Configurações

### 2. **BRANCH_STRATEGY.md** - Estratégia de Branches (GitHub Flow)
- Regras obrigatórias
- Nomenclatura (feat/, fix/, docs/, chore/)
- Fluxo passo a passo
- Proteções ativadas
- Comandos úteis
- O que fazer se errou

### 3. **COMMIT_GUIDE.md** - Padrão de Commits (Conventional Commits)
- Formato: tipo(escopo): descrição
- Tipos válidos (feat, fix, docs, test, chore, refactor, style, perf)
- Exemplos bons e ruins
- Fluxo completo
- Checklist antes de commitar
- Dicas profissionais

### 4. **IA_WORKFLOW.md** - Como Pedir pra Claude Fazer Coisas ⭐
- TL;DR (resumo rápido)
- Passo a passo: PRD → Prompt → Implementação
- Estrutura de um prompt efetivo
- Templates prontos pra copiar-colar
- Exemplos reais (feature, bug fix, refatoração, docs)
- O que pedir / O que não pedir
- Skills úteis (/commit, /review-pr, /simplify)
- Comparação: 90% mais rápido com IA!
- Erros comuns

### 5. **backend/README.md** - Setup do Backend
- Como configurar e rodar projeto
- Pré-requisitos (Docker)
- Docker setup
- Comandos principais
- Testando a API
- Desenvolvimento local
- Troubleshooting
- Arquitetura do projeto

### 6. **docs/PRD_*.md** - Especificações de Features
- `docs/PRD_USUARIOS.md` - Gerenciamento de Usuários ✅

---

## 🗂️ Estrutura de Pastas

```
projeto-final/
├── 📚 DOCUMENTACAO.md        ← VOCÊ ESTÁ AQUI
├── CLAUDE.md                  ← Instruções gerais
├── BRANCH_STRATEGY.md         ← Estratégia de branches
├── COMMIT_GUIDE.md            ← Padrão de commits
├── IA_WORKFLOW.md             ← Como usar IA
├── .claude/
│   └── settings.json          ← Config global (sem Co-Author, protege main)
├── docs/
│   └── PRD_USUARIOS.md        ← Specs de features
├── backend/
│   ├── README.md              ← Setup do backend
│   ├── main.py                ← Entrada da API
│   ├── requirements.txt        ← Dependências
│   ├── docker-compose.yml     ← Orquestração Docker
│   ├── Dockerfile             ← Imagem Docker
│   └── app/
│       ├── routes/            ← Endpoints HTTP
│       ├── controllers/        ← Orquestração
│       ├── services/           ← Lógica de negócio
│       ├── repositories/       ← Acesso ao banco
│       ├── models/             ← SQLAlchemy ORM
│       ├── dtos/              ← Validação Pydantic
│       ├── config/            ← Configurações
│       ├── ai/                ← Features de IA
│       └── integrations/      ← APIs externas
└── tests/
    ├── conftest.py            ← Fixtures
    ├── test_*.py              ← Testes de integração
    └── unit/
        └── test_*.py          ← Testes unitários
```

---

## 🎓 Fluxo de Trabalho Típico

### Cenário 1: Implementar uma Feature Rápido (Recomendado!) ⚡

```
1. Criar PRD em docs/PRD_FEATURE.md
2. Abrir IA_WORKFLOW.md
3. Copiar template de prompt
4. Disparar pro Claude Agent
5. IA implementa (tudo: código, testes, commits)
6. Você revisa e aprova
7. Merge!

TEMPO: 1 hora total (vs 4 horas manual)
```

### Cenário 2: Implementar Manualmente

```
1. Ler BRANCH_STRATEGY.md
2. git checkout -b feat/sua-feature
3. Implementar seguindo arquitetura
4. Ler COMMIT_GUIDE.md
5. git commit -m "feat(modulo): descrição"
6. git push -u origin feat/sua-feature
7. gh pr create
8. Merge!

TEMPO: 3-4 horas
```

### Cenário 3: Corrigir um Bug

```
1. Entender o problema
2. Criar branch: git checkout -b fix/seu-bug
3. Corrigir (manual ou com IA)
4. Testar (docker compose up + pytest)
5. Commit: git commit -m "fix(modulo): descrição"
6. Push + PR
7. Merge!

TEMPO: 1-2 horas
```

---

## 🚀 Comandos Rápidos

### Setup Inicial
```bash
# Clonar repo
git clone [repo-url]
cd projeto-final

# Subir backend
cd backend
docker compose up --build

# Em outra aba, subir frontend (futuro)
# cd frontend && npm start
```

### Desenvolver uma Feature
```bash
# Criar branch
git checkout -b feat/sua-feature

# Trabalhar, testar
# ...

# Commit
git commit -m "feat(modulo): descrição"

# Push
git push -u origin feat/sua-feature

# PR (CLI)
gh pr create --title "feat(modulo): descrição"
```

### Rodar Testes
```bash
# Entrar container
docker exec omniconnect-api bash

# Rodar testes
pytest tests/ -v --cov

# Com saída HTML
pytest --cov-report=html
```

---

## 📊 Padrões do Projeto

| Padrão | Localização | Usar Para |
|--------|-------------|----------|
| **Branches** | BRANCH_STRATEGY.md | feat/, fix/, docs/, chore/ |
| **Commits** | COMMIT_GUIDE.md | feat(modulo): descrição |
| **PRDs** | docs/PRD_*.md | Especificar features |
| **Arquitetura** | backend/README.md | routes → controllers → services |
| **IA Requests** | IA_WORKFLOW.md | Pedir pro Claude fazer |

---

## 🤖 IA & Ferramentas

### Claude Skills Disponíveis
- `/commit` - Fazer commits automaticamente
- `/review-pr` - Revisar PRs
- `/simplify` - Limpar código
- `/loop` - Rodar tarefas repetidamente

### Quando Usar IA
- ✅ Features novas
- ✅ Testes
- ✅ Refatoração
- ✅ Bug fixes
- ✅ Documentação

---

## 💡 Dicas da Equipe

1. **Sempre create um PRD antes** (evita retrabalho)
2. **Use IA pra features novas** (90% mais rápido)
3. **Revise tudo** (não confie cegamente)
4. **Testes primeiro** (TDD)
5. **Commits pequenos** (fácil de revisar)
6. **PRs com descrição** (contexto pro time)

---

## 🆘 Precisa de Ajuda?

### "Como faço...?"

- **...começar uma feature?** → Leia [`IA_WORKFLOW.md`](./IA_WORKFLOW.md)
- **...fazer um commit?** → Leia [`COMMIT_GUIDE.md`](./COMMIT_GUIDE.md)
- **...criar uma branch?** → Leia [`BRANCH_STRATEGY.md`](./BRANCH_STRATEGY.md)
- **...rodar o projeto?** → Leia [`backend/README.md`](./backend/README.md)
- **...usar Claude?** → Leia [`IA_WORKFLOW.md`](./IA_WORKFLOW.md)

---

## 📝 Versão da Documentação

- **Criada:** 2026-04-14
- **Stack:** FastAPI + SQLAlchemy + PostgreSQL
- **IA:** Claude (Haiku 4.5)
- **Time:** Alpha EdTech - Turma Aurora

---

**Pronto pra começar? Boa sorte! 🚀**
