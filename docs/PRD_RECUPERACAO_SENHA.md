# PRD — Recuperação de Senha via Email

**Projeto:** OmniConnect Fitness  
**Data:** 2026-05-10  
**Status:** Implementado e funcionando  
**Branch:** feat/password-recovery-system → mergeado em develop  

---

## 1. Problema

Usuários esquecem suas senhas e ficam bloqueados fora do sistema. Sem um fluxo de recuperação, a única saída é contatar o administrador para redefinição manual — o que não escala e prejudica a experiência do usuário.

---

## 2. Objetivo

Implementar um fluxo seguro, simples e auditável de recuperação de senha via email, acessível sem autenticação prévia.

---

## 3. Escopo

### Incluído nesta implementação

- Botão "Esqueceu sua senha?" na tela de login
- Tela de entrada de email para solicitar recuperação
- Geração de token temporário seguro (32 bytes aleatórios)
- Envio do token por email (link clicável com o token na URL)
- Tela de redefinição de senha com dois campos (nova senha + confirmação)
- Lista estática de requisitos de senha na tela de redefinição
- Invalidação do token após uso único
- Expiração automática do token (60 minutos)
- Hash seguro da nova senha (bcrypt)
- Invalidação de todos os JWTs anteriores (via `token_version`)
- Rate limiting por IP (slowapi)
- Roteamento web sem hash (`usePathUrlStrategy`) para deep links funcionarem

### Fora do escopo

- Indicador dinâmico de força de senha no frontend
- Recuperação por SMS ou WhatsApp
- Recuperação por perguntas de segurança
- Verificação em dois fatores (2FA)
- Código curto manual (apenas link no email)

---

## 4. Fluxo de Usuário

```
Tela de Login
    └─ [Esqueceu sua senha?]
         ↓
    ForgotPasswordScreen (/forgot-password)
         └─ [Usuário digita email e clica "Enviar Instruções"]
              ↓
         Backend processa (sem revelar se email existe)
         Gera token → Salva hash no banco → Envia email
              ↓
         Tela de Sucesso (mesmo para emails inexistentes)
         "Se existir conta, você receberá instruções"
              ↓
         [Usuário abre email → clica no link]
              ↓
         ResetPasswordScreen (/reset-password?token=abc123...)
              └─ [Usuário digita nova senha + confirmação]
                   ↓
              Backend valida token → Atualiza senha → Invalida token
                   ↓
              Login (com SnackBar verde de sucesso)
```

---

## 5. Regras de Negócio

| ID | Regra |
|----|-------|
| RN01 | O sistema nunca revela se um email está cadastrado (proteção anti-enumeração) |
| RN02 | O token expira em 60 minutos após geração (configurável via env) |
| RN03 | O token é de uso único: após usado, fica inválido permanentemente |
| RN04 | Se o usuário solicitar um novo token antes de o anterior expirar, o anterior é invalidado e um novo é gerado |
| RN05 | A nova senha deve ter: mínimo 8 caracteres, letra maiúscula, minúscula, número e caractere especial (`@$!%*?&_-`) |
| RN06 | Após reset bem-sucedido, o `token_version` do usuário é incrementado, invalidando todos os JWTs ativos |
| RN07 | O token nunca é armazenado em texto plano — apenas o hash SHA256 |
| RN08 | Rate limit: 5 tentativas/hora por IP para forgot-password; 10/hora para reset-password |

---

## 6. Endpoints de API

### POST /api/v1/auth/forgot-password

Solicita recuperação de senha.

**Request Body:**
```json
{
  "email": "usuario@email.com"
}
```

**Response (sempre HTTP 200):**
```json
{
  "message": "Se existir uma conta com este email, enviaremos instruções de recuperação."
}
```

**Segurança:** Retorna 200 mesmo que o email não exista, para prevenir enumeração.

**Rate limit:** 5 requisições/hora por IP.

---

### POST /api/v1/auth/reset-password

Redefine a senha usando o token recebido por email.

**Request Body:**
```json
{
  "token": "token_recebido_por_email",
  "new_password": "NovaSenha123!",
  "confirm_password": "NovaSenha123!"
}
```

**Response HTTP 200:**
```json
{
  "message": "Senha redefinida com sucesso. Faça login novamente."
}
```

**Erros possíveis:**
- `400` — Token inválido, expirado ou já utilizado
- `400` — Senhas não conferem
- `400` — Senha não atende requisitos de força
- `422` — Dados de entrada inválidos (validação Pydantic)
- `429` — Rate limit atingido (10/hora por IP)

---

## 7. Arquitetura

```
routes/password.py          → Endpoints HTTP + rate limiting (slowapi)
    ↓
controllers/password_controller.py   → Orquestra service + resposta HTTP
    ↓
services/password_service.py         → Lógica de negócio
    ├── gera token (secrets.token_urlsafe + sha256)
    ├── valida força de senha (regex)
    ├── valida token recebido
    └── atualiza senha + incrementa token_version
    ↓
repositories/password_reset_repository.py  → Acesso ao banco
    └── CRUD da tabela password_reset_tokens
    ↓
services/email_service.py   → Envio via Resend SDK v2
    └── template HTML com link de reset
```

---

## 8. Modelo de Dados

**Tabela: `password_reset_tokens`**

| Campo | Tipo (SQLAlchemy / PostgreSQL) | Descrição |
|-------|-------------------------------|-----------|
| id | UUID | Chave primária gerada automaticamente |
| user_id | UUID (FK → users.id) | Usuário dono do token |
| token_hash | VARCHAR(255) | Hash SHA256 do token (único, indexado) |
| expires_at | DateTime / TIMESTAMP | Data/hora de expiração (now + 60min, UTC naive) |
| used | BOOLEAN | Se o token já foi utilizado |
| used_at | DateTime / TIMESTAMP | Quando foi utilizado (NULL se não usado) |
| created_at | DateTime / TIMESTAMP | Data de criação (UTC naive, default server-side) |

> **Nota sobre timezone:** As colunas usam `DateTime` (SQLAlchemy) mapeado para `TIMESTAMP WITHOUT TIME ZONE` no PostgreSQL. Todos os datetimes são armazenados e comparados em UTC naive para consistência com o driver asyncpg.

**Coluna adicionada em `users`:**

| Campo | Tipo | Descrição |
|-------|------|-----------|
| token_version | INTEGER NOT NULL DEFAULT 0 | Incrementado a cada reset; invalida JWTs anteriores |

---

## 9. Dependências

| Biblioteca | Versão | Finalidade |
|------------|--------|-----------|
| resend | ≥2.0.0 | Envio de emails transacionais (gratuito: 100/dia) |
| slowapi | ≥0.1.9 | Rate limiting por IP |
| bcrypt | ≥4.1.0 | Hash seguro de senhas (já existia no projeto) |
| python-jose | ≥3.3.0 | JWT com campo `tv` (token_version) |
| secrets | stdlib | Geração criptograficamente segura do token |
| hashlib | stdlib | Hash SHA256 do token para armazenamento |

> **Nota sobre o SDK Resend v2:** A partir da versão 2.x, a integração usa a API estática de módulo: `resend.api_key = "..."` e `resend.Emails.send({...})` via `asyncio.to_thread()` (para não bloquear o event loop async). Versões anteriores (0.x / 1.x) têm API incompatível com a implementação atual.

---

## 10. Variáveis de Ambiente Necessárias

```bash
# Recuperação de Senha
PASSWORD_RESET_TOKEN_EXPIRE_MINUTES=60   # Expiração do token (minutos)
RESEND_API_KEY="re_sua_chave_aqui"       # API key do Resend (obrigatória)
RESEND_FROM_EMAIL="onboarding@resend.dev" # Email remetente
RESEND_FROM_NAME="OmniConnect Fitness"   # Nome do remetente

# URLs do Frontend (para o link no email)
FRONTEND_URL="http://localhost:3000"     # URL base do app Flutter Web
FRONTEND_RESET_PASSWORD_ROUTE="/reset-password"  # Rota da tela de reset
```

> **Requisito crítico:** O Flutter Web deve estar rodando na mesma porta definida em `FRONTEND_URL`. Veja as opções de execução abaixo.

---

## 11. Opções de Execução do Flutter (para testar)

O target web é necessário para testar o fluxo completo com deep links do email.

```bash
# Chrome (recomendado)
flutter run -d chrome --web-port 3000

# Microsoft Edge
flutter run -d edge --web-port 3000

# Servidor web — abrir qualquer browser em http://localhost:3000
flutter run -d web-server --web-port 3000

# Listar todos os dispositivos disponíveis
flutter devices
```

Para outros targets (Android, iOS, desktop), consulte [TUTORIAL_RECUPERACAO_SENHA.md](./TUTORIAL_RECUPERACAO_SENHA.md#5-opções-de-execução-do-flutter).

---

## 12. Telas Flutter Implementadas

| Tela | Arquivo | Rota |
|------|---------|------|
| Solicitar recuperação | `screens/auth/forgot_password_screen.dart` | `/forgot-password` |
| Redefinir senha | `screens/auth/reset_password_screen.dart` | `/reset-password?token=...` |

**Fix de deep link:** `usePathUrlStrategy()` foi adicionado em `main.dart` para ativar roteamento baseado em path (sem `#` na URL). Isso permite que o link do email (`/reset-password?token=...`) abra diretamente na tela correta via GoRouter.

---

## 13. Melhorias Futuras (não implementadas)

1. **Indicador dinâmico de força de senha** — Mostrar barra/badge em tempo real enquanto o usuário digita a nova senha.
2. **Cleanup agendado de tokens expirados** — Cron job ou background task no startup para limpar a tabela `password_reset_tokens`.
3. **Código curto para mobile nativo** — Trocar link por código de 6 dígitos (melhor UX sem deep links configurados).
4. **Rate limit por email** — Além do rate limit por IP, limitar também por endereço de email.
5. **Log de auditoria** — Registrar IP e timestamp de cada solicitação de reset.
6. **Notificação pós-reset** — Enviar email confirmando que a senha foi alterada (detecta uso indevido).
7. **Integração WhatsApp** — Enviar código de recuperação também via WhatsApp (infraestrutura já existe no projeto).
