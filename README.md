# 🏋️ OmniConnect Fitness

Plataforma de gestão de treinos e alimentação saudável com recomendações baseadas em IA.

---

## 📋 Visão Geral

**OmniConnect Fitness** é uma aplicação web e mobile completa voltada a personal trainers, alunos e administradores, oferecendo:

- Gerenciamento de usuários com sistema de convites
- Fichas de treino e logbook de atividades
- Planos de dieta e acompanhamento nutricional
- Metas fitness com acompanhamento de progresso
- Chatbot com IA para dúvidas sobre treino e nutrição
- Notificações via WhatsApp
- Interface responsiva com tema claro/escuro

**Status:** Em desenvolvimento (Sprint II)  
**Equipe:** FitLoop - Alpha EdTech  
**Última atualização:** Maio 2026

---

## 🛠 Stack Técnico

### Backend
- **Framework:** FastAPI (Python 3.11+)
- **Banco de Dados:** PostgreSQL + pgvector (busca vetorial para IA)
- **ORM:** SQLAlchemy (async)
- **Validação:** Pydantic v2
- **Segurança:** bcrypt, JWT (python-jose)
- **IA/RAG:** LangChain + LangChain-Groq + HuggingFace Embeddings
- **Testes:** pytest + pytest-asyncio + httpx

### Frontend
- **Framework:** Flutter (Web + iOS + Android)
- **Design:** Material Design 3
- **State Management:** Provider
- **Navegação:** go_router

### Infraestrutura
- **Containerização:** Docker + Docker Compose
- **Banco de imagem:** ankane/pgvector (PostgreSQL com suporte a vetores)

---

## 🚀 Quickstart

### Com Docker (Recomendado)

```bash
# 1. Clone o repositório
git clone <repo-url>
cd desafio-final/backend

# 2. Configure as variáveis de ambiente
cp .env.example .env
# Edite o .env com suas credenciais

# 3. Suba os containers
docker compose up -d

# 4. Crie o usuário admin inicial
docker compose exec api python seed_admin_data.py
```

**API disponível em:** `http://localhost:8000`  
**Documentação interativa (Swagger):** `http://localhost:8000/docs`

### Setup Local (sem Docker)

```bash
cd backend

# Criar e ativar venv
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate

# Instalar dependências
pip install -r requirements.txt

# Configurar ambiente
cp .env.example .env
# Edite o .env

# Iniciar servidor
uvicorn main:app --reload
```

---

## 📁 Estrutura do Projeto

```
desafio-final/
│
├── backend/
│   ├── app/
│   │   ├── ai/                   # RAG Chain (LangChain + Groq)
│   │   ├── config/               # Configurações (settings, database)
│   │   ├── controllers/          # Orquestração das requisições
│   │   ├── dependencies/         # Injeção de dependências (JWT)
│   │   ├── dtos/                 # Validação de entrada/saída (Pydantic)
│   │   ├── migrations/           # Scripts de migração do banco
│   │   ├── models/               # Modelos ORM (SQLAlchemy)
│   │   ├── repositories/         # Acesso ao banco de dados
│   │   ├── routes/               # Endpoints HTTP
│   │   ├── services/             # Lógica de negócio
│   │   └── tasks/                # Tarefas em background
│   ├── tests/                    # Testes automatizados
│   ├── scripts/                  # Scripts auxiliares
│   ├── main.py                   # Ponto de entrada da API
│   ├── seed_admin_data.py        # Script de seed inicial
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .env.example
│   └── README.md                 # Documentação detalhada do backend
│
├── frontend/
│   ├── lib/
│   │   ├── config/               # Configuração da API
│   │   ├── models/               # Modelos de dados
│   │   ├── providers/            # State management (Provider)
│   │   ├── routes/               # Navegação (go_router)
│   │   ├── screens/
│   │   │   ├── auth/             # Login, registro, código de convite
│   │   │   ├── admin/            # Painel administrativo
│   │   │   ├── student/          # Telas do aluno
│   │   │   └── trainer/          # Telas do personal trainer
│   │   ├── services/             # Chamadas à API
│   │   ├── shared/widgets/       # Componentes reutilizáveis (OmniCard, OmniButton...)
│   │   ├── theme/                # Tema claro/escuro
│   │   └── main.dart
│   ├── pubspec.yaml
│   └── README.md
│
├── docs/                         # PRDs e especificações
│   ├── PRD_USUARIOS.md
│   ├── PRD_FICHA_TREINO.md
│   ├── PRD_LOGBOOK.md
│   ├── PRD_DIETA.md
│   ├── PRD_METAS.md
│   └── ...outros PRDs
│
├── BRANCH_STRATEGY.md            # Estratégia de branches
├── COMMIT_GUIDE.md               # Padrão de commits
├── IA_WORKFLOW.md                # Como usar Claude para implementar
├── GIT_TROUBLESHOOTING.md        # Solução de problemas de Git
├── CLAUDE.md                     # ⭐ Instruções para Claude Code
└── README.md                     # Este arquivo
```

---

## 🔑 Variáveis de Ambiente

Copie `backend/.env.example` para `backend/.env` e preencha:

```env
# Aplicação
APP_NAME=OmniConnect
SECRET_KEY=sua-chave-secreta

# Banco de dados
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/omniconnect

# IA
GROQ_API_KEY=sua-chave-groq
GROQ_MODEL=llama3-8b-8192

# Integrações (opcionais)
WHATSAPP_TOKEN=...
FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
```

---

## 🧪 Testes

```bash
# Todos os testes
docker compose exec api pytest -v

# Com relatório de cobertura
docker compose exec api pytest --cov=app --cov-report=html

# Módulo específico
docker compose exec api pytest tests/test_users.py -v

# Sem Docker
cd backend
pytest -v --cov=app
```

---

## 📖 Documentação

| Documento | Descrição |
|-----------|-----------|
| [CLAUDE.md](./CLAUDE.md) ⭐ | Instruções obrigatórias para usar Claude Code no projeto |
| [backend/README.md](./backend/README.md) | Setup, arquitetura e padrões do backend |
| [frontend/README.md](./frontend/README.md) | Setup e telas do frontend |
| [BRANCH_STRATEGY.md](./BRANCH_STRATEGY.md) | Estratégia de branches e Git Flow |
| [COMMIT_GUIDE.md](./COMMIT_GUIDE.md) | Padrão de commits (Conventional Commits) |
| [IA_WORKFLOW.md](./IA_WORKFLOW.md) | Como pedir para Claude implementar features |
| [GIT_TROUBLESHOOTING.md](./GIT_TROUBLESHOOTING.md) | Soluções para problemas comuns de Git |

### PRDs (Product Requirements Documents)

Todos em `docs/`:

| PRD | Status |
|-----|--------|
| Usuários | ✅ Implementado |
| Ficha de Treino | ✅ Implementado |
| Logbook | ✅ Implementado |
| Dieta | ✅ Implementado |
| Metas | ✅ Implementado |
| Chatbot IA | ✅ Implementado |
| Dashboard Profissional | ✅ Implementado |
| Componentes Reutilizáveis | ✅ Implementado |
| Cadastro via WhatsApp | 🔄 Em andamento |
| Notificações | 🔄 Em andamento |

---

## 🔄 Git Workflow

```bash
# 1. Criar branch com padrão (feat/, fix/, docs/, etc.)
git checkout -b feat/sua-feature

# 2. Implementar e commitar
git add .
git commit -m "feat(modulo): descrição em português"

# 3. Push com -u (obrigatório na primeira vez)
git push -u origin feat/sua-feature

# 4. Verificar sincronização antes de abrir PR
git branch -vv   # deve mostrar [origin/feat/sua-feature]

# 5. Abrir PR contra develop (nunca contra main)
gh pr create --title "feat: sua feature" --base develop
```

**Regras obrigatórias:**
- ❌ Nunca commitar direto em `main` ou `develop`
- ✅ PRs sempre contra `develop`
- ✅ Conventional commits em português
- ✅ Sem `Co-Authored-By` (removido automaticamente)

---

## 🚨 Troubleshooting

```bash
# Resetar containers e volumes
docker compose down -v && docker compose up --build

# Problemas de Git
cat GIT_TROUBLESHOOTING.md

# Banco não inicializa
docker compose logs db

# API com erro 500
docker compose logs api
```

---

## 📞 Suporte

- **Dúvida sobre Git?** → [BRANCH_STRATEGY.md](./BRANCH_STRATEGY.md) ou [GIT_TROUBLESHOOTING.md](./GIT_TROUBLESHOOTING.md)
- **Padrão de commits?** → [COMMIT_GUIDE.md](./COMMIT_GUIDE.md)
- **Arquitetura do backend?** → [backend/README.md](./backend/README.md)
- **Como usar Claude?** → [IA_WORKFLOW.md](./IA_WORKFLOW.md)
- **Detalhes de uma feature?** → Veja o PRD correspondente em `docs/`

---

Desenvolvido pela equipe **FitLoop** — Alpha EdTech, Turma Aurora (2026)
