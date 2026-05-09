# PRD — Recuperação de Senha via Email

**Projeto:** OmniConnect Fitness  
**Data:** 2026-05-09  
**Status:** Implementado  
**Branch:** feat/password-recovery-system  

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
- Tela de redefinição de senha com validação de força
- Invalidação do token após uso único
- Expiração automática do token (60 minutos)
- Hash seguro da nova senha (bcrypt 12 rounds)
- Invalidação de todos os JWTs anteriores (via `token_version`)

### Fora do escopo

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
    ForgotPasswordScreen
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
              Login (com mensagem de sucesso após 2s)
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

---

## 7. Arquitetura

```
routes/password.py          → Endpoints HTTP + rate limiting
    ↓
controllers/password_controller.py   → Orquestra service + email + resposta
    ↓
services/password_service.py         → Lógica de negócio
    ├── gera token (secrets.token_urlsafe)
    ├── valida força de senha
    ├── valida token recebido
    └── atualiza senha + incrementa token_version
    ↓
repositories/password_reset_repository.py  → Acesso ao banco
    └── CRUD da tabela password_reset_tokens
    ↓
services/email_service.py   → Envio via Resend API
    └── template HTML com link de reset
```

---

## 8. Modelo de Dados

**Tabela: `password_reset_tokens`**

| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | UUID | Chave primária gerada automaticamente |
| user_id | UUID (FK → users.id) | Usuário dono do token |
| token_hash | VARCHAR(255) | Hash SHA256 do token (único, indexado) |
| expires_at | TIMESTAMPTZ | Data/hora de expiração (now + 60min) |
| used | BOOLEAN | Se o token já foi utilizado |
| used_at | TIMESTAMPTZ | Quando foi utilizado (NULL se não usado) |
| created_at | TIMESTAMPTZ | Data de criação |

---

## 9. Dependências

| Biblioteca | Versão | Finalidade |
|------------|--------|-----------|
| resend | ≥2.0.0 | Envio de emails transacionais (gratuito: 100/dia) |
| slowapi | ≥0.1.9 | Rate limiting por IP |
| bcrypt | ≥4.1.0 | Hash seguro de senhas |
| python-jose | ≥3.3.0 | JWT (token_version para invalidação) |
| secrets | stdlib | Geração criptograficamente segura do token |
| hashlib | stdlib | Hash SHA256 do token para armazenamento |

> **Nota sobre o SDK Resend v2:** A partir da versão 2.x, o SDK não expõe mais uma classe instanciável `Resend(api_key=...)`. A integração usa a API estática de módulo: `resend.api_key = "..."` e `resend.Emails.send({...})`. Versões anteriores (0.x / 1.x) têm API incompatível com a implementação atual.

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

> **Requisito crítico para o link do email funcionar:** O Flutter Web deve ser iniciado com a mesma porta definida em `FRONTEND_URL`. Exemplo: se `FRONTEND_URL=http://localhost:3000`, iniciar com:
> ```bash
> flutter run -d chrome --web-port 3000
> ```
> Sem a flag `--web-port`, o Flutter escolhe uma porta aleatória a cada execução. O link do email apontará para a porta errada e o Chrome exibirá erro de conexão.

---

## 11. Telas Flutter Implementadas

| Tela | Arquivo | Rota |
|------|---------|------|
| Solicitar recuperação | `screens/auth/forgot_password_screen.dart` | `/forgot-password` |
| Redefinir senha | `screens/auth/reset_password_screen.dart` | `/reset-password?token=...` |

---

## 12. Melhorias Futuras (não implementadas)

1. **Cleanup agendado** — O método `cleanup_expired_tokens()` já existe no `PasswordService` mas não está agendado. Poderia ser chamado via background task no startup da API ou via cron.
2. **Código curto para mobile nativo** — Trocar link por código de 6 dígitos que o usuário digita no app (melhor UX para mobile sem deep links configurados).
3. **Rate limit por email** — Além do rate limit por IP, limitar também por endereço de email.
4. **Log de auditoria** — Registrar IP e timestamp de cada solicitação de reset.
5. **Notificação pós-reset** — Enviar email confirmando que a senha foi alterada (detecta uso indevido).
6. **Integração WhatsApp** — Enviar código de recuperação também via WhatsApp (infraestrutura já existe no projeto).
