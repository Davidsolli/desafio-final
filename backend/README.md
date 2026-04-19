# OmniConnect Fitness — Backend 🏋️

> API REST com IA | Arquitetura em Camadas (Spring Boot Style para Python)

Backend do aplicativo OmniConnect Fitness construído com **FastAPI + SQLAlchemy + PostgreSQL + pgvector**.

---

## 🎯 Para Começar (Rápido!)

### Opção 1: Com Docker (Recomendado)

**Pré-requisito único:** Tenha o [Docker](https://www.docker.com/products/docker-desktop) instalado.

```bash
# 1. Acesse a pasta backend
cd backend

# 2. Inicie os containers (API + Banco de Dados)
docker compose up --build

# 3. Pronto! Acesse:
# - API Health Check: http://localhost:8000
# - Docs (Swagger): http://localhost:8000/docs
```

**Próxima vez:** Basta rodar `docker compose up` (sem `--build`)

### Opção 2: Localmente (Sem Docker)

**Pré-requisitos:** Python 3.9+, PostgreSQL 14+, pip

```bash
# 1. Criar banco de dados PostgreSQL
psql -U postgres
# CREATE USER omni_user WITH PASSWORD 'omni_pass';
# CREATE DATABASE omniconnect_db OWNER omni_user;
# \q

# 2. Configurar .env
cd backend
cp .env.example .env
# Editar: DATABASE_URL="postgresql://omni_user:omni_pass@localhost:5432/omniconnect_db"

# 3. Criar virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# ou venv\Scripts\activate  # Windows

# 4. Instalar dependências
pip install -r requirements.txt

# 5. Rodar servidor
uvicorn main:app --reload --port 8000

# 6. Acesse:
# - API: http://localhost:8000
# - Swagger: http://localhost:8000/docs
```

**Para mais detalhes, veja a seção "🛠️ Desenvolvimento Local" abaixo.**

---

## 📋 Pré-requisitos

- **Docker Desktop** (inclui Docker + Docker Compose)
  - [Download para Windows/Mac](https://www.docker.com/products/docker-desktop)
  - Para Linux: [Instruções de instalação](https://docs.docker.com/engine/install/)
- **Git** (para clonar/commitar o projeto)
- Terminal bash/zsh/PowerShell com Docker disponível

---

## 🐳 Como Funciona o Docker Setup

Nós **padronizamos tudo em Docker** para evitar conflitos de ambiente:

```
┌─────────────────────────────────────────────────────────┐
│                    Sua Máquina                          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │            Docker Compose Orquestra              │  │
│  │                                                  │  │
│  │  ┌──────────────────┐    ┌──────────────────┐  │  │
│  │  │   Container API  │    │  Container DB    │  │  │
│  │  │   (FastAPI)      │◄──►│  (PostgreSQL +   │  │  │
│  │  │   Porta 8000     │    │   pgvector)      │  │  │
│  │  │                  │    │   Porta 5432     │  │  │
│  │  └──────────────────┘    └──────────────────┘  │  │
│  │           ▲                       ▲             │  │
│  │           │ (Live Reload)        │             │  │
│  │           │ (Seu código aqui)    │             │  │
│  │  ┌────────┴──────────────────────┴────────┐   │  │
│  │  │     ./backend (Volumes Monte)          │   │  │
│  │  └─────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Benefícios:**
- ✅ Todos com o mesmo ambiente (sem "na minha máquina funciona")
- ✅ Sem instalar PostgreSQL, Python, dependências localmente
- ✅ Código muda → API recarrega automaticamente
- ✅ Dados persistem em volume Docker
- ✅ Fácil resetar: `docker compose down -v`

---

## 🚀 Comandos Principais

### Iniciar tudo
```bash
docker compose up --build   # Primeira vez
docker compose up            # Próximas vezes
```

### Parar os containers
```bash
docker compose down
```

### Resetar banco de dados completamente
```bash
docker compose down -v
docker compose up --build
```

### Ver logs da API
```bash
docker compose logs -f api
```

### Ver logs do Banco de Dados
```bash
docker compose logs -f db
```

### Conectar ao banco (PostgreSQL CLI)
```bash
docker exec -it omniconnect-db psql -U omni_user -d omniconnect_db
```

---

## 🧪 Testando a API

### Acessar endpoints (com Docker ou local)

Após rodar a API, estará disponível em:

| Recurso | URL |
|---------|-----|
| **Health Check** | http://localhost:8000 |
| **Docs Interativa (Swagger)** | http://localhost:8000/docs |
| **Docs Alternativa (ReDoc)** | http://localhost:8000/redoc |
| **OpenAPI Schema** | http://localhost:8000/openapi.json |

**Teste rápido no terminal:**
```bash
curl http://localhost:8000/
```

Você verá:
```json
{
  "status": "online",
  "message": "Servidor OmniConnect rodando com sucesso! 🚀",
  "docs": "Acesse http://localhost:8000/docs para ver a documentação interativa."
}
```

### Rodar Test Suite

**Com Docker:**
```bash
docker exec omniconnect-api pytest tests/ -v
```

**Localmente:**
```bash
# Com venv ativado
pytest tests/ -v

# Com cobertura
pytest tests/ -v --cov=app --cov-report=html

# Apenas testes de autenticação (novo!)
pytest tests/test_auth.py -v

# Apenas testes de usuários
pytest tests/test_users.py -v
```

**Resultado esperado:**
```
32 passed in 5.42s ✅
```

---

## 🛠️ Desenvolvimento Local

### Com Docker

**Editar Código:**
1. Abra qualquer arquivo em `backend/app/`
2. Salve o arquivo
3. A API recarrega automaticamente (Live Reload via volume Docker)
4. Teste a mudança em http://localhost:8000/docs

**Adicionar Dependências:**
1. Edite `backend/requirements.txt`
2. Rode: `docker compose up --build` (recria o container)

### Sem Docker (Python Local)

**Editar Código:**
1. Abra qualquer arquivo em `backend/app/`
2. Salve o arquivo
3. Uvicorn recarrega automaticamente (`--reload`)
4. Teste em http://localhost:8000/docs

**Adicionar Dependências:**
```bash
# Com venv ativado
pip install nova-dependencia
pip freeze > requirements.txt
```

**Variáveis de Ambiente:**
- Arquivo: `backend/.env` (crie se não existir)
- Copiar template: `cp .env.example .env`
- Editar com suas credenciais PostgreSQL e JWT SECRET_KEY
- Exemplo:
  ```env
  DATABASE_URL=postgresql://omni_user:omni_pass@localhost:5432/omniconnect_db
  SECRET_KEY=sua-chave-segura-minimo-32-caracteres
  OPENAI_API_KEY=seu-token-aqui
  ```


---

## ❌ Troubleshooting

### Com Docker

**"Porta 8000 já está em uso"**
```bash
# Parar todos os containers
docker compose down

# Ou usar porta diferente
docker compose up -d -e PORT=8001
```

**"Não consigo conectar ao banco"**
```bash
docker compose logs db
docker compose restart db
```

**"Mudei o código mas a API não recarregou"**
```bash
docker compose restart api
```

### Sem Docker (Local)

**"ModuleNotFoundError: No module named 'jose'"**
```bash
pip install python-jose[cryptography]
```

**"psycopg2: connection to server at 'localhost' failed"**
```bash
# Verificar se PostgreSQL está rodando
# Linux/Mac
brew services list | grep postgres

# Reiniciar PostgreSQL
brew services restart postgresql@14

# Verificar conexão
psql -U omni_user -d omniconnect_db -c "SELECT 1"
```

**"DATABASE_URL not set"**
```bash
# Criar .env a partir do template
cp .env.example .env

# Editar com credenciais reais
nano .env
```

**"Porta 8000 já está em uso"**
```bash
# Usar porta diferente
uvicorn main:app --reload --port 8001

# Ou matar processo
lsof -i :8000 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

**"FATAL: password authentication failed"**
```bash
# Verificar senha no .env
# Ou resetar no PostgreSQL
sudo -u postgres psql -c "ALTER USER omni_user WITH PASSWORD 'nova_senha';"
```

**"Testes falhando com erro de banco"**
```bash
# Limpar cache pytest
rm -rf .pytest_cache
pytest tests/ -v
```

---

## 📚 Documentação Adicional

- **Arquitetura:** Ver seção "📁 Arquitetura do Projeto" abaixo
- **Padrão de Commits:** [`COMMIT_GUIDE.md`](../COMMIT_GUIDE.md)
- **Uso com IA:** [`IA_WORKFLOW.md`](../IA_WORKFLOW.md)

---

## 📁 Arquitetura do Projeto (Spring Boot Style)

Usamos **arquitetura em camadas** para manter o código organizado, escalável e fácil de manter:

```
backend/
├── main.py                    ← Ponto de entrada (Inicia a API)
└── app/
    ├── routes/       → 🌐 Registra os endpoints HTTP (URLs)
    ├── controllers/  → 🎮 Recebe requisições e delega para services
    ├── dtos/         → 📦 Valida dados de entrada/saída (Pydantic)
    ├── services/     → 🧠 Lógica de negócio (Regra do sistema)
    ├── repositories/ → 💾 Acesso ao banco (ORM/SQL)
    ├── models/       → 📋 Estrutura das tabelas do banco
    ├── config/       → ⚙️ Variáveis de ambiente, JWT, segurança
    ├── ai/           → 🤖 Agentes, Skills e RAG (LangChain)
    └── integrations/ → 🔗 APIs externas (WhatsApp, Firebase)
```

### 🔄 Fluxo de uma Requisição

```
1. Cliente (App/WhatsApp)
   ↓
2. routes/ ← Mapeia URL para Controller
   ↓
3. controllers/ ← Recebe a requisição
   ↓
4. dtos/ ← Valida dados (Pydantic)
   ↓
5. services/ ← Executa lógica de negócio
   ↓
6. repositories/ ← Acessa/modifica banco de dados
   ↓
7. models/ ← Opera sobre as tabelas
   ↓
8. controllers/ ← Prepara resposta
   ↓
9. Cliente ← Recebe resposta JSON
```

### 📚 Exemplo Prático: Endpoint para criar treino

**Arquivo:** `app/routes/workouts.py`
```python
@router.post("/workouts")
async def create_workout(dto: CreateWorkoutDTO):
    # Chama o controller
    return await WorkoutController.create(dto)
```

**Arquivo:** `app/controllers/workout_controller.py`
```python
class WorkoutController:
    @staticmethod
    async def create(dto: CreateWorkoutDTO):
        # Chama service e retorna resultado
        return await WorkoutService.create(dto)
```

**Arquivo:** `app/services/workout_service.py`
```python
class WorkoutService:
    @staticmethod
    async def create(dto: CreateWorkoutDTO):
        # Lógica: validar, processar, chamar repository
        return await WorkoutRepository.save(dto)
```

**Arquivo:** `app/repositories/workout_repository.py`
```python
class WorkoutRepository:
    @staticmethod
    async def save(workout: Workout):
        # Executa: INSERT INTO workouts ...
        return await db.session.add_and_flush(workout)
```

---

## 💡 Quando Usar Cada Camada

| Camada | Responsabilidade | Exemplo |
|--------|------------------|---------|
| **routes/** | Mapear URLs para controllers | `POST /api/users` |
| **controllers/** | Receber request, chamar service | Validar autorização |
| **dtos/** | Validar e desserializar dados | `CreateUserDTO` com email válido |
| **services/** | Lógica de negócio | Calcular calorias queimadas |
| **repositories/** | ÚNICO lugar que toca DB | `SELECT * FROM users WHERE id = ?` |
| **models/** | Estrutura das tabelas | `class User(Base):` |
| **config/** | Configurações globais | `DATABASE_URL`, `JWT_SECRET` |
| **ai/** | Machine Learning/IA | Recomendação de exercícios com LLM |
| **integrations/** | APIs externas | Enviar mensagem WhatsApp |

---

## 📝 Padrões e Convenções

### Nomes de Arquivos
- Controllers: `user_controller.py`
- Services: `user_service.py`
- Repositories: `user_repository.py`
- Models: `user.py` (singular)
- DTOs: `create_user_dto.py`, `update_user_dto.py`

### Nomes de Classes
- Sempre **PascalCase**: `UserController`, `CreateUserDTO`
- Sufixos claros: `*Controller`, `*Service`, `*Repository`, `*DTO`

### Async/Await
- Use `async def` sempre que possível
- Prefira `asyncpg` para queries ao PostgreSQL

---

## 🔐 Segurança & Best Practices

- ✅ Queries **NUNCA** em strings brutas (use ORM)
- ✅ **Validação em DTOs** (Pydantic)
- ✅ **JWT** para autenticação
- ✅ Variáveis sensíveis em `.env`
- ✅ **CORS** configurado
- ✅ **Rate limiting** para APIs públicas

---

*Alpha EdTech · Turma Aurora · OmniConnect Fitness*
