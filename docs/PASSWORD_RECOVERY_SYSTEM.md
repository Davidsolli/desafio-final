# PRD — Sistema de Recuperação e Troca de Senha

## Projeto

OmniConnect Fitness

## Versão

1.0

## Data

08/05/2026

---

# 1. Objetivo

Implementar um sistema seguro de recuperação e troca de senha para usuários da plataforma OmniConnect Fitness.

A funcionalidade deverá permitir:

* recuperação de senha por email;
* redefinição de senha através de token temporário;
* troca de senha para usuários autenticados;
* confirmação de senha durante cadastro e alteração;
* proteção contra reutilização de tokens;
* mitigação de vulnerabilidades comuns relacionadas à autenticação.

---

# 2. Escopo

## 2.1 Incluído

* Recuperação de senha via email
* Envio de link temporário de redefinição
* Geração de token seguro
* Expiração automática de token
* Troca de senha autenticada
* Confirmação de senha
* Validação de força de senha
* Rate limiting
* Logs de auditoria básicos
* Integração com serviço de email
* Testes unitários e integração
* Compatibilidade com Docker
* Compatibilidade com PostgreSQL

## 2.2 Não Incluído

* MFA (autenticação multifator)
* Login social
* SMS recovery
* Autenticação biométrica
* Sessões multi-device avançadas
* Histórico de senhas
* Revogação global distribuída de JWT

---

# 3. Contexto Atual do Projeto

## 3.1 Stack Atual

### Backend

* FastAPI
* SQLAlchemy Async
* PostgreSQL
* pgvector
* Pydantic v2
* python-jose
* bcrypt

### Frontend

* React
* TypeScript

### Infraestrutura

* Docker
* Docker Compose
* WSL

---

# 4. Problema

Atualmente o sistema:

* não possui recuperação de senha;
* não possui troca de senha autenticada;
* não possui confirmação de senha;
* não possui envio de emails;
* não possui mecanismo de expiração/revogação de tokens de recuperação.

Impactos:

* usuários podem perder acesso permanentemente;
* alto risco de suporte manual;
* vulnerabilidades de UX e segurança;
* ausência de fluxo moderno de autenticação.

---

# 5. Objetivos Técnicos

## 5.1 Segurança

Garantir:

* tokens não previsíveis;
* tokens expirados automaticamente;
* tokens de uso único;
* proteção contra enumeração de emails;
* proteção contra brute force;
* armazenamento seguro de senha;
* armazenamento seguro de tokens.

## 5.2 Escalabilidade

A solução deve:

* funcionar em ambiente Docker;
* suportar múltiplos usuários simultaneamente;
* ser compatível com PostgreSQL;
* seguir arquitetura já existente do projeto.

## 5.3 Manutenibilidade

A implementação deve:

* seguir padrão atual do backend;
* manter separação em camadas;
* possuir testes automatizados;
* possuir documentação.

---

# 6. Arquitetura Escolhida

## 6.1 Tecnologias

### Recuperação de senha

* secrets.token_urlsafe()
* hashlib.sha256

### Hash de senha

* bcrypt

### Email

* Resend

### Banco

* PostgreSQL

### Validação

* Pydantic v2

### Rate limiting

* slowapi

---

# 7. Justificativa Técnica

## 7.1 Por que NÃO usar JWT para reset?

JWT não é ideal para recuperação de senha porque:

* não pode ser invalidado facilmente;
* não possui controle de uso único;
* dificulta revogação;
* aumenta complexidade desnecessária.

## 7.2 Por que usar token aleatório + hash?

A solução escolhida:

* é simples;
* é segura;
* é amplamente utilizada em SaaS modernos;
* permite revogação;
* permite expiração;
* evita armazenamento do token bruto no banco.

Fluxo:

1. gerar token aleatório;
2. gerar SHA256 do token;
3. salvar hash no banco;
4. enviar token bruto por email;
5. validar hash posteriormente.

---

# 8. Fluxos Funcionais

# 8.1 Fluxo — Esqueci Minha Senha

## Etapas

1. Usuário acessa tela de recuperação.
2. Usuário informa email.
3. Backend gera token temporário.
4. Backend salva hash do token.
5. Backend envia email.
6. Usuário acessa link.
7. Usuário redefine senha.
8. Token é invalidado.
9. Usuário realiza login novamente.

---

# 8.2 Fluxo — Troca de Senha

## Etapas

1. Usuário autenticado acessa configurações.
2. Usuário informa senha atual.
3. Usuário informa nova senha.
4. Usuário confirma nova senha.
5. Backend valida senha atual.
6. Backend valida nova senha.
7. Backend atualiza senha.
8. JWTs antigos tornam-se inválidos.

---

# 8.3 Fluxo — Confirmação de Senha

## Aplicável em

* cadastro;
* recuperação;
* troca de senha.

## Regra

Campos:

* password
* confirm_password

Devem possuir exatamente o mesmo valor.

---

# 9. Regras de Negócio

## 9.1 Token de recuperação

* Deve expirar em 60 minutos
* Deve ser de uso único
* Deve possuir alta entropia
* Não pode ser reutilizado
* Não pode ser armazenado em texto puro

## 9.2 Senha

A senha deve:

* possuir mínimo de 8 caracteres;
* possuir letra maiúscula;
* possuir letra minúscula;
* possuir número;
* possuir caractere especial.

## 9.3 Troca de senha

* nova senha deve ser diferente da atual;
* senha atual deve ser validada;
* usuário deve estar autenticado.

## 9.4 Segurança

* forgot-password deve sempre retornar HTTP 200;
* sistema nunca deve informar se email existe;
* rate limiting obrigatório.

---

# 10. Estrutura de Banco de Dados

# 10.1 Tabela password_reset_tokens

## Objetivo

Armazenar tokens temporários de redefinição.

## Campos

| Campo      | Tipo         | Descrição       |
| ---------- | ------------ | --------------- |
| id         | UUID         | Chave primária  |
| user_id    | UUID         | FK usuário      |
| token_hash | VARCHAR(255) | Hash SHA256     |
| expires_at | TIMESTAMP    | Expiração       |
| used       | BOOLEAN      | Token utilizado |
| used_at    | TIMESTAMP    | Data de uso     |
| created_at | TIMESTAMP    | Data criação    |

## Índices

* index(token_hash)
* index(user_id)
* index(expires_at)

---

# 10.2 Campo token_version

## Objetivo

Invalidar JWTs antigos após troca de senha.

## Adição na tabela users

| Campo         | Tipo    | Descrição           |
| ------------- | ------- | ------------------- |
| token_version | INTEGER | Versão do token JWT |

## Regra

Ao alterar senha:

* token_version += 1

Todos JWTs antigos tornam-se inválidos.

---

# 11. Estrutura Backend

## Arquivos Novos

```txt
backend/app/
├── models/
│   └── password_reset_token.py
│
├── repositories/
│   └── password_reset_repository.py
│
├── services/
│   ├── password_service.py
│   └── email_service.py
│
├── controllers/
│   └── password_controller.py
│
├── dtos/
│   ├── forgot_password_dto.py
│   ├── reset_password_dto.py
│   └── change_password_dto.py
│
├── routes/
│   └── password.py
│
└── migrations/
    └── create_password_reset_tokens.py
```

---

# 12. Estrutura Frontend

```txt
frontend/
├── pages/
│   ├── ForgotPasswordPage.tsx
│   ├── ResetPasswordPage.tsx
│   └── ChangePasswordPage.tsx
│
├── components/
│   ├── PasswordInput.tsx
│   ├── PasswordConfirmInput.tsx
│   └── PasswordStrengthMeter.tsx
│
├── hooks/
│   └── usePassword.ts
│
└── services/
    └── authService.ts
```

---

# 13. Endpoints

# 13.1 Recuperação de senha

## POST /api/v1/auth/forgot-password

### Request

```json
{
  "email": "user@example.com"
}
```

### Response

```json
{
  "message": "Se existir uma conta com este email, enviaremos instruções."
}
```

### Observações

* Sempre retornar HTTP 200
* Rate limit obrigatório

---

# 13.2 Reset de senha

## POST /api/v1/auth/reset-password

### Request

```json
{
  "token": "TOKEN",
  "new_password": "SenhaNova123!",
  "confirm_password": "SenhaNova123!"
}
```

### Response

```json
{
  "message": "Senha alterada com sucesso"
}
```

---

# 13.3 Troca de senha autenticada

## PUT /api/v1/users/me/password

### Request

```json
{
  "current_password": "SenhaAtual123!",
  "new_password": "SenhaNova123!",
  "confirm_password": "SenhaNova123!"
}
```

### Response

```json
{
  "message": "Senha alterada com sucesso"
}
```

---

# 14. DTOs

## ForgotPasswordDTO

Campos:

* email

## ResetPasswordDTO

Campos:

* token
* new_password
* confirm_password

## ChangePasswordDTO

Campos:

* current_password
* new_password
* confirm_password

---

# 15. Variáveis de Ambiente

```env
# Password Recovery
PASSWORD_RESET_TOKEN_EXPIRE_MINUTES=60
PASSWORD_RESET_SECRET_KEY="super-secret-key"

# Resend
RESEND_API_KEY="re_xxxxx"
RESEND_FROM_EMAIL="no-reply@omniconnect.fit"
RESEND_FROM_NAME="OmniConnect"

# Frontend
FRONTEND_URL="http://localhost:3000"
FRONTEND_RESET_PASSWORD_ROUTE="/auth/reset-password"

# Rate Limit
PASSWORD_RESET_RATE_LIMIT="5/hour"
```

---

# 16. Dependências

## Backend

```txt
resend
slowapi
```

Observação:

* itsdangerous NÃO será utilizado.
* tokens serão gerados com secrets.token_urlsafe().

---

# 17. Segurança

## 17.1 Proteções Obrigatórias

### Enumeração de emails

Mitigação:

* sempre retornar HTTP 200.

### Reutilização de token

Mitigação:

* marcar token como usado.

### Token expirado

Mitigação:

* validar expires_at.

### Banco comprometido

Mitigação:

* salvar apenas hash SHA256.

### Brute force

Mitigação:

* rate limiting.

### Interceptação de tráfego

Mitigação:

* HTTPS obrigatório em produção.

### Senha fraca

Mitigação:

* regex forte.

---

# 18. Rate Limiting

## Forgot Password

* 5 requests/hora por IP
* 3 requests/hora por email

## Reset Password

* 10 requests/hora por IP

---

# 19. Emails

## Template

O email deve conter:

* nome do usuário;
* link de redefinição;
* prazo de expiração;
* aviso de segurança.

## Exemplo de link

```txt
https://app.omniconnect.fit/auth/reset-password?token=TOKEN
```

---

# 20. Testes

## Testes Unitários

* geração de token;
* hash de token;
* expiração;
* validação de senha;
* comparação de senha.

## Testes de Integração

* envio de email;
* reset completo;
* troca autenticada;
* invalidação de token.

## Testes de Segurança

* rate limit;
* reutilização;
* enumeração;
* token expirado.

---

# 21. Critérios de Aceite

## Recuperação de senha

* usuário recebe email;
* token expira corretamente;
* token não reutiliza;
* senha é atualizada;
* login funciona após redefinição.

## Troca de senha

* senha atual é validada;
* nova senha é persistida;
* JWTs antigos tornam-se inválidos.

## Segurança

* email nunca é exposto;
* tokens nunca ficam em texto puro;
* sistema possui rate limiting.

---

# 22. Ordem Recomendada de Implementação

## Fase 1 — Infraestrutura

* dependências
* variáveis ambiente
* configuração email

## Fase 2 — Banco

* migration
* model
* repository

## Fase 3 — Backend

* services
* controllers
* rotas
* DTOs

## Fase 4 — Frontend

* telas
* formulários
* validações

## Fase 5 — Segurança

* rate limiting
* logs
* auditoria

## Fase 6 — Testes

* unitários
* integração
* segurança

---

# 23. Compatibilidade

## Compatível com

* FastAPI
* SQLAlchemy
* PostgreSQL
* Docker
* Docker Compose
* React
* TypeScript
* WSL

---

# 24. Próximos Passos

1. Aprovação do PRD
2. Criar branch:

```txt
feat/password-recovery-system
```

3. Implementar backend
4. Implementar frontend
5. Criar testes
6. Abrir Pull Request
7. Deploy em staging
8. Deploy em produção

---

# 25. Conclusão

A solução proposta oferece:

* arquitetura moderna;
* segurança adequada;
* boa experiência de usuário;
* escalabilidade;
* compatibilidade com o stack atual;
* baixo acoplamento;
* facilidade de manutenção.

A implementação seguirá padrões modernos utilizados em aplicações SaaS profissionais.
