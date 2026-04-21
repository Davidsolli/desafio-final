# PRD: Cadastro Inicial via WhatsApp - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-04-20  
**Status:** 📋 Em Especificação  
**Responsável:** David Oliveira

---

## 📋 1. Visão Geral

### Objetivo
Implementar um fluxo de cadastro seguro via WhatsApp que:
- ✅ Valida posso de telefone com OTP (One-Time Password)
- ✅ Permite criar conta sem usar email inicialmente
- ✅ Usuário define senha segura APÓS validar OTP (no app, não WhatsApp)
- ✅ Suporta PhoneAuth nativo para UX simplificada
- ✅ Integra com WhatsApp Cloud API (Meta)

### Por Quê?
O OmniConnect precisa de um onboarding rápido e seguro pois:
- **Problema:** Usuários fitness resistem a formulários longos
- **Solução:** Validar só número no cadastro → dados complementares depois (phased)
- **Segurança:** OTP via WhatsApp é mais seguro que SMS (E2E encryption)
- **UX:** Usuário usa app que já conhece (WhatsApp)
- **Custo:** OTP WhatsApp é barato (~R$ 0.05/mensagem após 1.000 grátis)

### Escopo
✅ **Incluído neste PRD:**
- Envio de OTP via WhatsApp Business API (Meta)
- Validação de OTP com retry logic
- Criação de usuário após validar OTP
- Formulário de dados complementares (phased onboarding)
- Testes automatizados
- Segurança (rate limiting, validação, hashing)

❌ **NÃO incluído (futuro PRD):**
- Login com OTP (será login.email + password)
- Recuperação de senha via email
- 2FA adicional
- Integração com Evolution API (apenas Cloud API)
- Social login (Google, Facebook)

---

## 📊 2. Especificação Técnica

### 2.1 Fluxo de Cadastro (3 Etapas)

```
ETAPA 1: Validação de Número + OTP
  ├─ Usuário insere: +55 11 98765-4321
  ├─ Backend gera OTP 6 dígitos: "123456"
  ├─ Armazena no Redis (TTL 15 min)
  ├─ Envia via WhatsApp Cloud API
  └─ Usuário copia código do WhatsApp

ETAPA 2: Confirmação de OTP
  ├─ Usuário cola código no app: "123456"
  ├─ Backend valida contra Redis
  ├─ Retorna pre_auth_token (válido 30 min)
  └─ Frontend pode resend OTP se expirou

ETAPA 3: Dados Complementares + Senha
  ├─ Frontend lida formulário:
  │  ├─ Nome (obrigatório)
  │  ├─ Email (obrigatório)
  │  ├─ Senha (obrigatório, forte)
  │  ├─ Altura (opcional, para IMC)
  │  ├─ Peso (opcional, para IMC)
  │  └─ Objetivo (opcional)
  └─ Backend cria User + retorna JWT
```

### 2.2 Modelo de Dados

#### Tabela: User (Existente - Adicionar Campo)

```python
class User(Base):
    """Usuário do sistema"""
    
    __tablename__ = "users"
    
    # Campos existentes
    id: UUID
    name: str
    email: str
    password: str
    role: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    
    # Novos campos para WhatsApp cadastro
    phone_whatsapp: str          # Número validado no cadastro
    phone_verified_at: datetime  # Quando foi verificado
    phone_verified: bool         # Já passou por OTP?
```

#### Tabela: OTPCache (Temporária - Redis)

```python
# Não é uma tabela SQL, mas armazenamento Redis temporário:

KEY: otp:{phone}
VALUE: {
    "code": "123456",
    "created_at": "2026-04-20T10:30:00Z",
    "attempts": 0,
    "max_attempts": 3,
    "ttl": 900  # 15 minutos em segundos
}

KEY: pre_auth:{phone}
VALUE: {
    "token": "abc123xyz...",
    "phone": "+5511987654321",
    "created_at": "2026-04-20T10:30:00Z",
    "ttl": 1800  # 30 minutos em segundos
}
```

### 2.3 DTOs (Data Transfer Objects)

#### SendOTPDTO (Etapa 1)
```json
{
  "phone": "+55 11 98765-4321"
}
```

**Validações:**
- ✅ `phone`: Obrigatório, formato +55 XX XXXXX-XXXX, válido segundo libphonenumbers
- ✅ Não pode já ter usuário com este telefone
- ✅ Não pode ter enviado OTP há menos de 30 segundos (rate limiting)
- ✅ Máximo 5 envios por hora por IP

#### SendOTPResponseDTO
```json
{
  "status": "sent",
  "message": "Código enviado para WhatsApp",
  "expires_in": 900,
  "retry_available_in": 0
}
```

---

#### VerifyOTPDTO (Etapa 2)
```json
{
  "phone": "+55 11 98765-4321",
  "otp": "123456"
}
```

**Validações:**
- ✅ `phone`: Obrigatório, válido
- ✅ `otp`: Obrigatório, 6 dígitos
- ✅ Máximo 3 tentativas erradas → bloqueia por 5 min
- ✅ OTP não expirou (< 15 min)

#### VerifyOTPResponseDTO
```json
{
  "pre_auth_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 1800,
  "next_step": "complete_registration",
  "phone": "+5511987654321"
}
```

---

#### CompleteRegistrationDTO (Etapa 3)
```json
{
  "pre_auth_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "name": "João Silva",
  "email": "joao@email.com",
  "password": "SenhaForte123!",
  "height": 1.75,
  "weight": 85.5,
  "objective": "weight_loss"
}
```

**Validações:**
- ✅ `pre_auth_token`: Válido e não expirado
- ✅ `name`: 3-255 chars, apenas letras (sem números)
- ✅ `email`: Válido, não pode ser duplicado no banco
- ✅ `password`: Mínimo 8 chars, maiúscula, minúscula, número, especial
- ✅ `height`: 1.40 - 2.20 metros (validação biométrica)
- ✅ `weight`: 30 - 300 kg (validação biométrica)
- ✅ `objective`: enum ["weight_loss", "muscle_gain", "maintenance"]

#### CompleteRegistrationResponseDTO (Usuário Criado)
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 86400,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "João Silva",
    "email": "joao@email.com",
    "phone_whatsapp": "+5511987654321",
    "phone_verified": true,
    "role": "client",
    "created_at": "2026-04-20T10:30:00Z"
  }
}
```

---

## 🔌 3. Endpoints HTTP

### 3.1 POST `/api/v1/auth/whatsapp/send-otp` (Etapa 1)

**Descrição:** Envia OTP via WhatsApp para validar número

**Request:**
```http
POST /api/v1/auth/whatsapp/send-otp HTTP/1.1
Content-Type: application/json

{
  "phone": "+55 11 98765-4321"
}
```

**Response 200 (Sucesso):**
```json
{
  "status": "sent",
  "message": "Código enviado para WhatsApp",
  "expires_in": 900,
  "retry_available_in": 0
}
```

**Response 400 (Validação):**
```json
{
  "detail": "Telefone inválido"
}
```

**Response 409 (Conflito):**
```json
{
  "detail": "Usuário já cadastrado com este número"
}
```

**Response 429 (Rate Limit):**
```json
{
  "detail": "Muitas tentativas. Tente novamente em 60 segundos",
  "retry_available_in": 60
}
```

---

### 3.2 POST `/api/v1/auth/whatsapp/verify-otp` (Etapa 2)

**Descrição:** Valida OTP e retorna pre_auth_token

**Request:**
```http
POST /api/v1/auth/whatsapp/verify-otp HTTP/1.1
Content-Type: application/json

{
  "phone": "+55 11 98765-4321",
  "otp": "123456"
}
```

**Response 200 (Sucesso):**
```json
{
  "pre_auth_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 1800,
  "next_step": "complete_registration",
  "phone": "+5511987654321"
}
```

**Response 400 (Validação):**
```json
{
  "detail": "OTP inválido ou expirado"
}
```

**Response 401 (Não Autorizado):**
```json
{
  "detail": "Código incorreto. 2 tentativas restantes"
}
```

**Response 429 (Bloqueado):**
```json
{
  "detail": "Muitas tentativas erradas. Bloqueado por 5 minutos",
  "retry_available_in": 300
}
```

---

### 3.3 POST `/api/v1/auth/whatsapp/resend-otp` (Retry)

**Descrição:** Reenvia OTP se usuário não recebeu (opcional)

**Request:**
```http
POST /api/v1/auth/whatsapp/resend-otp HTTP/1.1
Content-Type: application/json

{
  "phone": "+55 11 98765-4321"
}
```

**Response:** Mesmo que 3.1

**Regra:** Pode resend max 1x por minuto

---

### 3.4 POST `/api/v1/auth/whatsapp/complete-registration` (Etapa 3)

**Descrição:** Completa cadastro com dados complementares + cria senha

**Request:**
```http
POST /api/v1/auth/whatsapp/complete-registration HTTP/1.1
Content-Type: application/json

{
  "pre_auth_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "name": "João Silva",
  "email": "joao@email.com",
  "password": "SenhaForte123!",
  "height": 1.75,
  "weight": 85.5,
  "objective": "weight_loss"
}
```

**Response 201 (Sucesso):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 86400,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "João Silva",
    "email": "joao@email.com",
    "phone_whatsapp": "+5511987654321",
    "phone_verified": true,
    "role": "client",
    "created_at": "2026-04-20T10:30:00Z"
  }
}
```

**Response 400 (Validação):**
```json
{
  "detail": "Email já cadastrado no sistema"
}
```

**Response 401 (Token Inválido):**
```json
{
  "detail": "Pre-auth token inválido ou expirado"
}
```

---

## 🔐 4. Requisitos de Segurança

### 4.1 WhatsApp Cloud API
- ✅ Usar oficial Meta API (não Evolution API)
- ✅ Access token armazenado em variáveis de ambiente
- ✅ Usar HTTPS para toda comunicação
- ✅ Validar webhook assinatura (X-Hub-Signature)
- ✅ Suportar SMS fallback (se WhatsApp falhar)

### 4.2 OTP
- ✅ 6 dígitos aleatórios (100.000 - 999.999)
- ✅ Válido por 15 minutos (TTL)
- ✅ Nunca log o OTP completo (logar XXX-123 apenas)
- ✅ Armazenar APENAS no Redis (não banco SQL)
- ✅ Deletar após validação
- ✅ Hash de tentativas para detectar brute force

### 4.3 Rate Limiting
```
Envio OTP:
  - Max 5 por hora por IP
  - Min 30 segundos entre envios
  - Max 1 resend por minuto

Validação OTP:
  - Max 3 tentativas erradas
  - Bloqueio por 5 minutos após 3 erros
  - Limpar bloqueio após 1 hora

Pre-Auth Token:
  - Válido por 30 minutos apenas
  - Não reutilizável (deletar após usar)
  - Vinculado ao pre_auth_token (não ao número)
```

### 4.4 Validação de Dados
- ✅ Email: Regex válido + unique no banco
- ✅ Altura/Peso: Range biométrico (1.40-2.20m, 30-300kg)
- ✅ Senha: 8+ chars, maiúscula, minúscula, número, especial
- ✅ Telefone: libphonenumbers validação
- ✅ Nome: Sem números, 3-255 chars

### 4.5 Privacidade & LGPD
- ✅ Não armazenar OTP em logs
- ✅ Não armazenar passwords em logs
- ✅ Usar hashes bcrypt para senha
- ✅ TTL curto em dados sensíveis (Redis)
- ✅ Consentimento implícito ao cadastro

---

## 🧪 5. Testes Automatizados

### 5.1 Testes de Integração (test_whatsapp_registration.py)

**Teste 1: Enviar OTP com sucesso**
- ✅ POST /send-otp com número válido
- ✅ Retorna 200 + status "sent"
- ✅ OTP criado no Redis
- ✅ WhatsApp API chamada (mock)

**Teste 2: Enviar OTP com número duplicado**
- ✅ Usuário já existe
- ✅ Retorna 409 "Usuário já cadastrado"

**Teste 3: Enviar OTP com número inválido**
- ✅ Formato inválido (+55999)
- ✅ Retorna 400 "Telefone inválido"

**Teste 4: Rate limiting - muitos envios**
- ✅ 5+ envios em 1 hora do mesmo IP
- ✅ Retorna 429 + retry_available_in

**Teste 5: Validar OTP correto**
- ✅ POST /verify-otp com OTP válido
- ✅ Retorna 200 + pre_auth_token
- ✅ OTP deletado do Redis

**Teste 6: Validar OTP incorreto**
- ✅ OTP errado
- ✅ Retorna 401 "Código incorreto"
- ✅ Incrementa contador de tentativas

**Teste 7: Bloquear após 3 erros**
- ✅ 3x OTP errado
- ✅ 4ª tentativa retorna 429 (bloqueado por 5 min)

**Teste 8: OTP expirado**
- ✅ OTP gerado, espera 15+ minutos
- ✅ Retorna 400 "OTP expirado"

**Teste 9: Completar registro com dados válidos**
- ✅ POST /complete-registration com pre_auth_token válido
- ✅ Retorna 201 + access_token
- ✅ Usuário criado no banco
- ✅ Senha hasheada

**Teste 10: Completar registro - pre_auth_token inválido**
- ✅ Token fake ou expirado
- ✅ Retorna 401

**Teste 11: Completar registro - email duplicado**
- ✅ Email já existe
- ✅ Retorna 400

**Teste 12: Completar registro - senha fraca**
- ✅ Password: "123" (muito fraca)
- ✅ Retorna 400 "Senha inválida"

**Teste 13: Completar registro - altura/peso inválidos**
- ✅ Height: 0.5 (muito baixo)
- ✅ Weight: 500 (muito alto)
- ✅ Retorna 400 "Dados biométricos inválidos"

**Teste 14: Resend OTP com sucesso**
- ✅ POST /resend-otp
- ✅ Novo OTP gerado
- ✅ Anterior deletado

**Teste 15: Resend OTP - rate limit**
- ✅ 2+ resends em 1 minuto
- ✅ Retorna 429

---

### 5.2 Testes Unitários

**test_whatsapp_otp_service.py:**
- OTP é 6 dígitos
- OTP é aleatório (não sequencial)
- Validação de telefone
- Validação de senha (força)
- Validação de altura/peso

**test_whatsapp_dto_validation.py:**
- DTOs válidos passam
- DTOs inválidos falham
- Email regex correto
- Telefone formato brasileiro

**test_whatsapp_security.py:**
- Senha hasheada (não texto plano)
- OTP deletado após validação
- Pre-auth token não reutilizável
- Rate limiting funciona

---

## 📋 6. Critérios de Aceitação

### User Story 1: Enviar OTP via WhatsApp
```
DADO que um novo usuário quer se cadastrar
QUANDO ele insere seu número: +55 11 98765-4321
E clica em "Enviar Código"
ENTÃO recebe resposta 200 + status "sent"
E o código é enviado no WhatsApp (não SMS)
E o código é válido por 15 minutos
E pode reenviá-lo (máximo 1x por minuto)
```

### User Story 2: Validar OTP
```
DADO que o usuário recebeu o OTP no WhatsApp
QUANDO ele copia o código e cola no app
ENTÃO recebe resposta 200 + pre_auth_token
E pode prosseguir para dados complementares
E se errar 3x é bloqueado por 5 minutos
```

### User Story 3: Criar Conta com Dados Complementares
```
DADO que o usuário validou o OTP
QUANDO ele preenche nome, email, senha, altura, peso
E envia o formulário
ENTÃO recebe resposta 201 + access_token
E a conta é criada no banco
E senha é armazenada com hash bcrypt
E pode fazer login imediatamente
```

### User Story 4: Segurança
```
DADO que o envio de OTP
QUANDO analisamos os logs
ENTÃO nunca encontramos OTP em texto plano
E nunca encontramos senhas em texto plano
E OTP é armazenado apenas em Redis (temporário)
```

---

## 📁 7. Arquivos a Criar

```
backend/
├── app/
│   ├── routes/
│   │   └── auth_whatsapp.py           # 3 endpoints
│   ├── services/
│   │   ├── whatsapp_service.py        # Integração Meta API
│   │   └── whatsapp_otp_service.py    # Lógica OTP
│   ├── dtos/
│   │   └── auth_whatsapp_dto.py       # DTOs
│   ├── config/
│   │   ├── whatsapp_config.py         # Variáveis Meta
│   │   └── redis_config.py            # Redis para OTP
│   └── repositories/
│       └── otp_repository.py          # Ops com Redis
│
├── tests/
│   ├── test_whatsapp_registration.py  # Integração (15 testes)
│   └── unit/
│       ├── test_whatsapp_otp_service.py
│       ├── test_whatsapp_dto_validation.py
│       └── test_whatsapp_security.py
│
└── requirements.txt
    ├── redis                  # Cache OTP
    ├── requests               # HTTP para Meta API
    ├── phonenumbers           # Validação telefone
    └── python-whatsapp (opt) # SDK Meta (se usar)
```

---

## ⚡ 8. Ordem de Implementação

### Fase 1: Configuração (1-2h)
```
1. Setup Meta Business Manager + WABA
2. Gerar Access Token Meta
3. Criar template OTP pre-aprovado
4. Setup Redis locally + testes
5. Adicionar env vars (.env)
```

### Fase 2: Estrutura Base (1-2h)
```
6. Criar config/whatsapp_config.py
7. Criar config/redis_config.py
8. Criar dtos/auth_whatsapp_dto.py
9. Criar app/repositories/otp_repository.py
```

### Fase 3: Lógica de OTP (1-2h)
```
10. Criar services/whatsapp_otp_service.py
11. Criar services/whatsapp_service.py (Meta API)
12. Testar envio OTP manualmente
```

### Fase 4: API (1-2h)
```
13. Criar routes/auth_whatsapp.py (3 endpoints)
14. Integrar com User model/repository
15. Adicionar rate limiting
16. Registrar rotas em main.py
```

### Fase 5: Testes (2-3h)
```
17. Criar tests/test_whatsapp_registration.py (15+ testes)
18. Criar tests/unit/* (4+ testes)
19. Validar cobertura > 80%
20. Testar com número real
```

---

## 🎯 9. Definição de Pronto ("Done")

Cadastro WhatsApp está **pronto** quando:

- ✅ Todos os 3 endpoints funcionam
- ✅ OTP gerado aleatoriamente (6 dígitos)
- ✅ OTP enviado via WhatsApp (não SMS)
- ✅ Validação de OTP com retry logic (3 tentativas)
- ✅ Pre-auth token gerado após validar OTP
- ✅ Dados complementares validados (email, altura, peso)
- ✅ Usuário criado no banco após complete-registration
- ✅ Senha hasheada com bcrypt
- ✅ Rate limiting implementado
- ✅ Testes de integração: **15+ testes passando**
- ✅ Testes unitários: **4+ testes passando**
- ✅ Cobertura de testes: **≥ 80%**
- ✅ Documentação no Swagger (`/docs`)
- ✅ Nenhum log com OTP/senha em texto plano
- ✅ Pre-auth token não reutilizável
- ✅ Testado com número real (WhatsApp)
- ✅ Funciona sem SMS fallback (apenas WhatsApp)

---

## 📊 10. Requisitos Mapeados do PDF

| Requisito | ID | Status |
|-----------|-----|--------|
| Cadastro inicial via WhatsApp conversacional | RF-01 | ✅ Este PRD |
| Chatbot coleta nome, data, peso, altura, objetivo | RF-55 | ✅ Step 3 |
| Sincronização <2s após conclusão WhatsApp | RNF-01 | ✅ Async |
| Criar automaticamente perfil no banco | RF-56 | ✅ Complete-reg |
| Notificar Gestor de novo cadastro | RF-57 | ⏳ Futuro PRD |
| Dados sincronizados em <2s | RNF-01 | ✅ Async/Webhook |

---

## 💼 11. Regras de Negócio Aplicáveis

| Regra | Implementação |
|-------|--------------|
| RN-04: Cadastro via WhatsApp só conclui com aprovação | Pre-auth token |
| Usuário só pode ter 1 número WhatsApp | Unique constraint |
| OTP expira em 15 minutos | Redis TTL |
| Máximo 3 tentativas OTP erradas | Counter em Redis |
| Senha deve ser forte | Validação Pydantic |

---

## ⚙️ 12. Configurações Necessárias

### .env (Adicionar)
```bash
# WhatsApp Cloud API (Meta)
WHATSAPP_BUSINESS_ACCOUNT_ID=your-waba-id
WHATSAPP_PHONE_NUMBER_ID=your-phone-id
WHATSAPP_API_VERSION=v19.0
WHATSAPP_ACCESS_TOKEN=your-access-token

# Redis (para OTP)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=optional

# OTP Settings
OTP_LENGTH=6
OTP_EXPIRY_SECONDS=900  # 15 min
OTP_MAX_ATTEMPTS=3
OTP_BLOCK_DURATION=300  # 5 min

# Rate Limiting
RATE_LIMIT_SEND_OTP_PER_HOUR=5
RATE_LIMIT_SEND_OTP_MIN_INTERVAL=30  # segundos
RATE_LIMIT_VERIFY_OTP_MAX_ATTEMPTS=3
```

### docker-compose.yml (Adicionar Redis)
```yaml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes

volumes:
  redis_data:
```

---

## 🔗 13. Integração com Serviços Externos

### Meta WhatsApp Cloud API
```
Endpoint: https://graph.instagram.com/v19.0/{phone_id}/messages
Método: POST
Autenticação: Bearer {access_token}
Rate Limit: 80 requisições/segundo
Fallback: SMS se WhatsApp falhar
```

### Redis (Local)
```
Host: localhost
Port: 6379
Keys:
  - otp:{phone} → código + metadata
  - pre_auth:{phone} → token + metadata
  - rate_limit:{ip}:send_otp → contador
  - blocked:{phone} → flag bloqueio
```

---

## 📝 Notas Finais

### Dependências com Outros PRDs
- **PRD_USUARIOS.md**: Estende User model com phone_verified
- **PRD_AUTENTICACAO_LOGIN.md** (futuro): Login com email+password (não OTP)
- **PRD_NOTIFICACOES.md** (futuro): Notificar Gestor de novo cadastro

### Adaptações Futuras
- Suporte a múltiplos números por usuário
- Autenticação de dois fatores com OTP
- Login passwordless permanente (se desejar)
- Social login (Google, Apple)

---

## 📞 14. Dúvidas e Decisões

| Dúvida | Decisão | Por quê |
|--------|---------|--------|
| OTP em todas as vezes que loga? | Não, apenas cadastro | Melhor UX + reduz custos |
| Suportar SMS fallback? | Sim, custos baixos | Confiabilidade |
| Guardar OTP em DB? | Não, apenas Redis | Privacidade + performance |
| Pre-auth token reutilizável? | Não, deletar após usar | Segurança |
| Permitir skip dados complementares? | Não, obrigatório | Integridade de dados |

---

## 📖 Referências

- [Meta WhatsApp Cloud API Docs](https://developers.facebook.com/docs/whatsapp/cloud-api)
- [WhatsApp Authentication Templates](https://developers.facebook.com/docs/whatsapp/cloud-api/reference/message-templates)
- [OWASP OTP Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [Phone Number Validation - libphonenumbers](https://github.com/daviddrysdale/python-phonenumbers)
- [Redis TTL Documentation](https://redis.io/commands/expire)

---

*Criado para: OmniConnect Fitness - Alpha EdTech*  
*Arquitetura: FastAPI + Redis + WhatsApp Cloud API (Meta)*  
*Responsável: Equipe Backend*  
*Data: 2026-04-20*
