# PRD: Gerenciamento de Usuários - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-04-14  
**Status:** ✅ Aprovado  
**Responsável:** David Oliveira

---

## 📋 1. Visão Geral

### Objetivo
Criar um sistema completo de gerenciamento de usuários que permita:
- ✅ Registro/Cadastro de novos usuários
- ✅ Autenticação via email e senha
- ✅ Gerenciamento de perfis (roles)
- ✅ Ativação/Desativação de contas
- ✅ Armazenamento seguro de dados

### Por Quê?
O OmniConnect precisa de um sistema de usuários robusto como **base para todo o aplicativo**. Sem isso, não conseguimos:
- Autenticar quem está acessando
- Personalizar experiência por role (admin, personal trainer, cliente)
- Integrar com WhatsApp (precisamos do `phone_whatsapp`)
- Rastrear histórico de ações

### Escopo
✅ **Incluído neste PRD:**
- Criar novo usuário (POST /api/v1/users)
- Listar usuários (GET /api/v1/users)
- Buscar usuário por ID (GET /api/v1/users/{id})
- Atualizar usuário (PUT /api/v1/users/{id})
- Deletar usuário (DELETE /api/v1/users/{id})
- Testes automatizados
- Validações de segurança

❌ **NÃO incluído (futuro PRD):**
- Login/Autenticação (será um PRD separado)
- Reset de senha
- 2FA (autenticação de dois fatores)
- Integração com WhatsApp

---

## 📊 2. Especificação Técnica

### 2.1 Modelo de Dados

```python
class User(Base):
    """Tabela de usuários do sistema"""
    
    __tablename__ = "users"
    
    # Campos da tabela
    id: UUID              # Identificador único (gerado automaticamente)
    name: str             # Nome completo do usuário (obrigatório, max 255 chars)
    email: str            # Email único (obrigatório, validado com regex)
    password: str         # Senha hash (obrigatório, nunca armazenar em texto plano)
    role: str             # Papel do usuário (obrigatório)
                          # Valores: "admin", "personal_trainer", "client"
    phone_whatsapp: str   # Número WhatsApp (obrigatório para integração, formato: +55 11 99999-9999)
    is_active: bool       # Conta ativa/inativa? (padrão: True)
    created_at: datetime  # Data de criação (automático, nunca muda)
    updated_at: datetime  # Data da última atualização (automático, atualiza a cada mudança)
```

### 2.2 DTOs (Data Transfer Objects)

**Por quê DTOs?** Para validar dados de entrada antes de processar, e formatar dados de saída sem expor senhas/dados sensíveis.

#### CreateUserDTO (Entrada - Criar usuário)
```json
{
  "name": "João Silva",
  "email": "joao@example.com",
  "password": "SenhaForte123!",
  "role": "client",
  "phone_whatsapp": "+55 11 99999-9999"
}
```

**Validações:**
- ✅ `name`: Obrigatório, 3-255 caracteres, sem números
- ✅ `email`: Obrigatório, válido (regex), único no banco
- ✅ `password`: Obrigatório, mínimo 8 caracteres, deve ter: maiúscula, minúscula, número, caractere especial
- ✅ `role`: Obrigatório, deve ser um de: "admin", "personal_trainer", "client"
- ✅ `phone_whatsapp`: Obrigatório, formato: +55 11 XXXXX-XXXX

#### UpdateUserDTO (Entrada - Atualizar usuário)
```json
{
  "name": "João Silva Santos",
  "phone_whatsapp": "+55 11 98888-8888",
  "role": "personal_trainer",
  "is_active": true
}
```

**Validações:** Mesmas de CreateUserDTO, mas **TODOS os campos são opcionais** (só atualiza o que vem)

⚠️ **NÃO se pode atualizar:**
- Email (precisaria de verificação de propriedade)
- Password (será um endpoint separado)
- created_at (nunca muda)

#### UserResponseDTO (Saída)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "João Silva",
  "email": "joao@example.com",
  "role": "client",
  "phone_whatsapp": "+55 11 99999-9999",
  "is_active": true,
  "created_at": "2026-04-14T10:30:00Z",
  "updated_at": "2026-04-14T10:30:00Z"
}
```

⚠️ **Nunca retornar:** `password` (por segurança)

---

## 🔌 3. Endpoints HTTP

### 3.1 POST /api/v1/users (Criar usuário)

**Descrição:** Registra um novo usuário no sistema

**Request:**
```http
POST /api/v1/users HTTP/1.1
Content-Type: application/json

{
  "name": "João Silva",
  "email": "joao@example.com",
  "password": "SenhaForte123!",
  "role": "client",
  "phone_whatsapp": "+55 11 99999-9999"
}
```

**Response 201 (Sucesso):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "João Silva",
  "email": "joao@example.com",
  "role": "client",
  "phone_whatsapp": "+55 11 99999-9999",
  "is_active": true,
  "created_at": "2026-04-14T10:30:00Z",
  "updated_at": "2026-04-14T10:30:00Z"
}
```

**Response 400 (Erro de Validação):**
```json
{
  "detail": "Email já existe no sistema"
}
```

**Erros possíveis:**
| Código | Motivo |
|--------|--------|
| 400 | Email já cadastrado, senha fraca, email inválido, role inválido |
| 409 | Conflito (ex: email duplicado) |
| 500 | Erro interno do servidor |

---

### 3.2 GET /api/v1/users (Listar todos os usuários)

**Descrição:** Retorna lista paginada de todos os usuários

**Request:**
```http
GET /api/v1/users?page=1&limit=10 HTTP/1.1
```

**Response 200:**
```json
{
  "total": 150,
  "page": 1,
  "limit": 10,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "João Silva",
      "email": "joao@example.com",
      "role": "client",
      "phone_whatsapp": "+55 11 99999-9999",
      "is_active": true,
      "created_at": "2026-04-14T10:30:00Z",
      "updated_at": "2026-04-14T10:30:00Z"
    },
    ...
  ]
}
```

**Parâmetros (Query):**
- `page`: Página (padrão: 1)
- `limit`: Itens por página (padrão: 10, máximo: 100)

---

### 3.3 GET /api/v1/users/{id} (Buscar usuário por ID)

**Descrição:** Retorna os dados de um usuário específico

**Request:**
```http
GET /api/v1/users/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
```

**Response 200:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "João Silva",
  "email": "joao@example.com",
  "role": "client",
  "phone_whatsapp": "+55 11 99999-9999",
  "is_active": true,
  "created_at": "2026-04-14T10:30:00Z",
  "updated_at": "2026-04-14T10:30:00Z"
}
```

**Response 404:**
```json
{
  "detail": "Usuário não encontrado"
}
```

---

### 3.4 PUT /api/v1/users/{id} (Atualizar usuário)

**Descrição:** Atualiza dados de um usuário (campos opcionais)

**Request:**
```http
PUT /api/v1/users/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
Content-Type: application/json

{
  "name": "João Silva Santos",
  "phone_whatsapp": "+55 11 98888-8888",
  "is_active": true
}
```

**Response 200:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "João Silva Santos",
  "email": "joao@example.com",
  "role": "client",
  "phone_whatsapp": "+55 11 98888-8888",
  "is_active": true,
  "created_at": "2026-04-14T10:30:00Z",
  "updated_at": "2026-04-14T15:45:00Z"
}
```

**Response 404:**
```json
{
  "detail": "Usuário não encontrado"
}
```

---

### 3.5 DELETE /api/v1/users/{id} (Deletar usuário)

**Descrição:** Remove um usuário do sistema

**Request:**
```http
DELETE /api/v1/users/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
```

**Response 204 (Sem conteúdo - Sucesso):**
```
(sem body)
```

**Response 404:**
```json
{
  "detail": "Usuário não encontrado"
}
```

⚠️ **Nota:** Consideramos usar soft delete (marcar como deletado) em vez de hard delete (remover do banco) para manter histórico. Decidir com a equipe.

---

## 🔐 4. Requisitos de Segurança

### 4.1 Armazenamento de Senha
- ✅ **NUNCA** armazenar em texto plano
- ✅ Usar hash com **bcrypt** (padrão da indústria)
- ✅ Exemplo: `bcrypt.hashpw(senha.encode(), bcrypt.gensalt())`

### 4.2 Validação de Email
- ✅ Usar regex para validar formato
- ✅ Verificar se email é único no banco (UNIQUE constraint)
- ✅ Não permitir domínios suspeitos

### 4.3 Validação de Senha
- ✅ Mínimo 8 caracteres
- ✅ Pelo menos 1 maiúscula
- ✅ Pelo menos 1 minúscula
- ✅ Pelo menos 1 número
- ✅ Pelo menos 1 caractere especial (!@#$%^&*)

### 4.4 Prevenção de Ataques
- ✅ SQL Injection: Usar ORM (SQLAlchemy), **NUNCA** queries brutas
- ✅ XSS: Sempre validar entrada com Pydantic
- ✅ Rate Limiting: Limitar criação de usuários (ex: máximo 5 por IP por hora)

### 4.5 Dados Sensíveis
- ✅ Nunca retornar `password` na API
- ✅ Nunca logar senhas
- ✅ Usar variáveis de ambiente para chaves

---

## 🧪 5. Testes Automatizados

### 5.1 Estrutura de Testes

```
backend/tests/
├── conftest.py                    # Fixtures compartilhadas
├── test_users.py                  # Testes de integração
└── unit/
    ├── test_user_model.py         # Testes unitários do Model
    ├── test_user_dto.py           # Testes unitários das DTOs
    ├── test_user_service.py       # Testes unitários do Service
    └── test_user_repository.py    # Testes unitários do Repository
```

### 5.2 Testes de Integração (test_users.py)

**Teste 1: Criar usuário com dados válidos**
```python
def test_create_user_success():
    """Deve criar usuário com status 201"""
    response = POST /api/v1/users com dados válidos
    assert response.status_code == 201
    assert response.body["id"] existe
    assert response.body["email"] == "joao@example.com"
```

**Teste 2: Criar usuário com email duplicado**
```python
def test_create_user_email_duplicate():
    """Deve retornar erro 409 se email já existe"""
    # Criar primeiro usuário
    POST /api/v1/users com email "joao@example.com"
    # Tentar criar outro com mesmo email
    response = POST /api/v1/users com email "joao@example.com"
    assert response.status_code == 409
    assert "Email já existe" in response.body["detail"]
```

**Teste 3: Criar usuário com senha fraca**
```python
def test_create_user_weak_password():
    """Deve rejeitar senhas fracas"""
    response = POST /api/v1/users com password "123"
    assert response.status_code == 400
    assert "senha deve ter" in response.body["detail"]
```

**Teste 4: Listar usuários com paginação**
```python
def test_list_users_pagination():
    """Deve retornar usuários paginados"""
    response = GET /api/v1/users?page=1&limit=10
    assert response.status_code == 200
    assert response.body["total"] existe
    assert len(response.body["data"]) <= 10
```

**Teste 5: Buscar usuário por ID**
```python
def test_get_user_by_id():
    """Deve retornar usuário quando ID existe"""
    user_id = "550e8400-e29b-41d4-a716-446655440000"
    response = GET /api/v1/users/{user_id}
    assert response.status_code == 200
    assert response.body["id"] == user_id
```

**Teste 6: Buscar usuário inexistente**
```python
def test_get_user_not_found():
    """Deve retornar 404 se usuário não existe"""
    response = GET /api/v1/users/id-inexistente
    assert response.status_code == 404
```

**Teste 7: Atualizar usuário**
```python
def test_update_user():
    """Deve atualizar dados do usuário"""
    user_id = criar_usuario()
    response = PUT /api/v1/users/{user_id} com name="Novo Nome"
    assert response.status_code == 200
    assert response.body["name"] == "Novo Nome"
    assert response.body["updated_at"] > created_at
```

**Teste 8: Deletar usuário**
```python
def test_delete_user():
    """Deve deletar usuário com status 204"""
    user_id = criar_usuario()
    response = DELETE /api/v1/users/{user_id}
    assert response.status_code == 204
    # Verificar que não existe mais
    response_get = GET /api/v1/users/{user_id}
    assert response_get.status_code == 404
```

### 5.3 Testes Unitários

**test_user_dto.py: Validações de DTO**
```python
def test_create_user_dto_valid():
    """DTO válido deve passar"""
    dto = CreateUserDTO(
        name="João Silva",
        email="joao@example.com",
        password="SenhaForte123!",
        role="client",
        phone_whatsapp="+55 11 99999-9999"
    )
    assert dto.name == "João Silva"

def test_create_user_dto_invalid_email():
    """DTO com email inválido deve falhar"""
    with pytest.raises(ValidationError):
        CreateUserDTO(
            name="João Silva",
            email="email-invalido",  # Email sem @
            password="SenhaForte123!",
            role="client",
            phone_whatsapp="+55 11 99999-9999"
        )
```

**test_user_service.py: Lógica de negócio**
```python
def test_hash_password():
    """Senha deve ser hasheada, nunca em texto plano"""
    service = UserService()
    senha_texto_plano = "SenhaForte123!"
    senha_hasheada = service.hash_password(senha_texto_plano)
    assert senha_hasheada != senha_texto_plano
    assert service.verify_password(senha_texto_plano, senha_hasheada)
```

---

## 📋 6. Critérios de Aceitação

### User Story 1: Registrar Novo Usuário
```
DADO que um cliente quer se registrar no OmniConnect
QUANDO ele acessa POST /api/v1/users com dados válidos
ENTÃO ele recebe resposta 201 com seu ID e dados
E a senha é armazenada com hash bcrypt
E o email é único no banco
```

### User Story 2: Listar Usuários
```
DADO que existem múltiplos usuários no banco
QUANDO admin acessa GET /api/v1/users?page=1&limit=10
ENTÃO recebe resposta 200 com lista paginada
E cada usuário não mostra a senha
E total de itens é exato
```

### User Story 3: Validação de Dados
```
DADO que um usuário tenta registrar com dados inválidos
QUANDO envia email inválido OU senha fraca
ENTÃO recebe erro 400 com mensagem clara
E nenhum usuário é criado
```

### User Story 4: Segurança
```
DADO que senhas são armazenadas
QUANDO alguém tenta acessar o banco diretamente
ENTÃO vê apenas hashes bcrypt, nunca texto plano
E não consegue fazer reverse engineering
```

---

## 📁 7. Arquivos a Criar

```
backend/
├── app/
│   ├── models/
│   │   └── user.py                 # Model SQLAlchemy
│   ├── dtos/
│   │   └── user_dto.py             # CreateUserDTO, UpdateUserDTO, UserResponseDTO
│   ├── services/
│   │   └── user_service.py         # Lógica de negócio (hash, validação)
│   ├── repositories/
│   │   └── user_repository.py      # Acesso ao banco (CRUD)
│   ├── controllers/
│   │   └── user_controller.py      # Orquestra chamadas
│   └── routes/
│       └── user.py                 # Endpoints HTTP
├── tests/
│   ├── conftest.py                 # Fixtures (usuario_mock, client_db, etc)
│   ├── test_users.py               # Testes de integração
│   └── unit/
│       ├── test_user_model.py
│       ├── test_user_dto.py
│       ├── test_user_service.py
│       └── test_user_repository.py
└── requirements.txt
    ├── pytest                       # Framework de testes
    ├── pytest-asyncio               # Suporte a testes async
    ├── httpx                        # Cliente HTTP para testes
    └── bcrypt                       # Hash de senhas
```

---

## ⚡ 8. Ordem de Implementação

### Fase 1: Estrutura Base (1-2h)
```
1. Criar app/models/user.py
2. Criar app/dtos/user_dto.py
3. Adicionar bcrypt ao requirements.txt
```

### Fase 2: Lógica de Negócio (1-2h)
```
4. Criar app/services/user_service.py (hash, validação)
5. Criar app/repositories/user_repository.py (CRUD)
```

### Fase 3: API (1-2h)
```
6. Criar app/controllers/user_controller.py
7. Criar app/routes/user.py
8. Registrar rotas no main.py
```

### Fase 4: Testes (2-3h)
```
9. Criar tests/conftest.py (fixtures)
10. Criar tests/test_users.py (integração)
11. Criar tests/unit/* (unitários)
12. Rodar `pytest` e validar cobertura > 80%
```

---

## 🎯 9. Definição de Pronto ("Done")

Endpoint está **pronto** quando:

- ✅ Todos os 5 endpoints funcionam (`POST`, `GET /`, `GET /{id}`, `PUT`, `DELETE`)
- ✅ Validações de DTO funcionam (email válido, senha forte, role válido)
- ✅ Testes de integração: **8+ testes passando**
- ✅ Testes unitários: **5+ testes passando**
- ✅ Cobertura de testes: **≥ 80%**
- ✅ Documentação automática no Swagger (`/docs`) funciona
- ✅ Não há hardcodes, tudo via variáveis de ambiente
- ✅ Código segue padrão do projeto (arquitetura em camadas)
- ✅ Passwords são hasheadas com bcrypt
- ✅ Nunca retorna senha na resposta

---

## 📞 10. Dúvidas e Decisões

| Dúvida | Decisão | Por quê |
|--------|---------|--------|
| Hard delete ou soft delete? | **Soft delete** (marcar como deletado) | Manter auditoria e histórico |
| Email única? | **Sim, UNIQUE constraint** | Evitar múltiplas contas com mesmo email |
| Roles apenas "admin", "personal_trainer", "client"? | **Sim, enum** | Facilita segurança e permissões |
| Testar com banco real ou mock? | **Banco real (Docker)** | Mais realista e confiável |

---

## 📝 Notas Finais

🎓 **Sobre este PRD:**
- Ficou bem completo? Sim, cobrir requisitos, testes, segurança.
- Está muito técnico? Um pouco, mas necessário para dev implementar.
- Faltou algo? Não, temos: endpoints, DTOs, validações, testes, segurança, ordem de trabalho.

**Próximos PRDs podem ser mais curtos**, este é o template.

---

*Criado para: OmniConnect Fitness - Alpha EdTech*  
*Arquitetura: FastAPI + SQLAlchemy + PostgreSQL*
