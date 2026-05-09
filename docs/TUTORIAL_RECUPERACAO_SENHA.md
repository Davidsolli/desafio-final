# Tutorial — Sistema de Recuperação de Senha

**Projeto:** OmniConnect Fitness  
**Data:** 2026-05-09  

---

## 1. Como a funcionalidade funciona

### Visão geral

O sistema de recuperação de senha permite que usuários que esqueceram sua senha recebam por email um link temporário para criar uma nova senha. O fluxo é:

```
Usuário esquece senha
    → Solicita recuperação informando email
    → Sistema verifica se email existe (sem revelar ao usuário)
    → Se existir, gera token seguro e envia email com link
    → Usuário clica no link → tela de redefinição abre com token
    → Usuário define nova senha
    → Sistema valida token + nova senha → atualiza banco
    → Usuário faz login com nova senha
```

### Por que não armazenamos o token em texto puro?

O token enviado por email (`token_raw`) é gerado com `secrets.token_urlsafe(32)` — 32 bytes aleatórios convertidos para base64 URL-safe. No banco, salvamos apenas o **hash SHA256** desse token (`token_hash`).

Quando o usuário envia o token, fazemos hash do que chegou e comparamos com o que está no banco. Se bater, é válido.

**Vantagem:** Se o banco for comprometido, o atacante tem apenas hashes inutilizáveis — impossível reverter para o token original.

### Como o token é invalidado?

Existem 3 mecanismos de invalidação:
1. **Uso único:** após usado, o campo `used = True` e qualquer nova tentativa com o mesmo token é rejeitada
2. **Expiração:** o token tem `expires_at = now + 60min`; se expirado, é rejeitado
3. **Novo pedido:** se o usuário solicitar recuperação de novo antes de expirar, o token anterior é deletado e um novo é gerado

### Como isso invalida sessões abertas (JWT)?

O modelo `User` tem um campo `token_version` (inteiro). Quando a senha é redefinida, incrementamos esse número. Cada JWT contém o `token_version` do momento da criação. Na validação do JWT, comparamos o `token_version` do banco com o do JWT — se forem diferentes, o JWT é rejeitado com 401. Isso invalida automaticamente todas as sessões abertas sem precisar de uma blacklist.

---

## 2. Como configurar

### 2.1 Requisitos

- Docker e Docker Compose instalados
- Conta gratuita no [Resend](https://resend.com) (100 emails gratuitos/dia)
- Flutter SDK instalado (para o frontend)

### 2.2 Configurar o Resend

1. Acesse https://resend.com e crie uma conta gratuita
2. No painel, vá em **API Keys** → **Create API Key**
3. Copie a chave gerada (começa com `re_`)
4. No plano gratuito, o email de saída é `onboarding@resend.dev` (sem configuração extra)
5. Para domínio próprio, adicione e verifique um domínio em **Domains**

### 2.3 Configurar as variáveis de ambiente

Edite o arquivo `backend/.env` e configure:

```bash
# Email (obrigatório para recuperação de senha)
RESEND_API_KEY="re_sua_chave_aqui"
RESEND_FROM_EMAIL="onboarding@resend.dev"   # No plano grátis, use este
RESEND_FROM_NAME="OmniConnect Fitness"

# URL do frontend (onde o Flutter Web está rodando)
FRONTEND_URL="http://localhost:3000"
FRONTEND_RESET_PASSWORD_ROUTE="/reset-password"

# Expiração do token (em minutos)
PASSWORD_RESET_TOKEN_EXPIRE_MINUTES=60
```

**Importante sobre `FRONTEND_URL`:**
- Em desenvolvimento local: `http://localhost:3000` (ou a porta onde Flutter Web está rodando)
- Em produção: URL pública do app (ex: `https://app.omniconnect.fit`)

### 2.4 Subir o ambiente

```bash
# Na pasta backend/
cd backend
docker compose up

# Em outro terminal, subir o Flutter Web
# ⚠️ OBRIGATÓRIO: usar --web-port com a mesma porta do FRONTEND_URL no .env
cd frontend
flutter run -d chrome --web-port 3000
```

> **Por que a porta fixa é obrigatória:** sem `--web-port`, o Flutter escolhe uma porta aleatória a cada execução. O link enviado no email aponta para `http://localhost:3000`. Se o app estiver em outra porta, o Chrome abrirá uma página de erro, não o app. O `--web-port 3000` garante que o link do email sempre carregará a tela de redefinição corretamente.

---

## 3. Como testar

### Teste rápido via Swagger UI

1. Acesse http://localhost:8000/docs
2. Clique em `POST /api/v1/auth/forgot-password`
3. Clique em "Try it out"
4. Coloque `{"email": "email_cadastrado@dominio.com"}`
5. Clique "Execute"
6. Resposta deve ser: `{"message": "Se existir uma conta com este email..."}`
7. Verifique o email na caixa de entrada

### Teste completo pelo app

1. Abra http://localhost:3000 no navegador
2. Na tela de login, clique "Esqueceu sua senha?"
3. Digite o email cadastrado
4. Clique "Enviar Instruções"
5. Abra o email recebido e clique no botão "Redefinir Minha Senha"
6. O browser abre em `/reset-password?token=...`
7. Digite nova senha e confirme
8. Após sucesso, faça login com a nova senha

---

## 4. Exemplos de fluxo

### Exemplo 1 — Usuário comum (cliente)

```
1. João (cliente) abre o app e não lembra a senha
2. Clica "Esqueceu sua senha?"
3. Digita: joao@gmail.com
4. Clica "Enviar Instruções"
5. App mostra: "Email Enviado! ⏰ O link expira em 60 minutos"
6. João abre o email → clica no botão azul "Redefinir Minha Senha"
7. Abre a tela com campos "Nova Senha" e "Confirmar Senha"
8. João digita: NovaSenha123!
9. Indicador fica verde: "Forte"
10. Confirma a senha
11. Clica "Redefinir Senha"
12. Mensagem verde: "Senha redefinida com sucesso!"
13. App volta para login automaticamente após 2 segundos
14. João faz login com NovaSenha123! → acessa o app normalmente
```

### Exemplo 2 — Personal trainer (segundo pedido)

```
1. Maria (personal trainer) solicita recuperação
2. Recebe Email 1 com Link 1
3. Antes de usar, solicita de novo (esqueceu que já pediu)
4. Recebe Email 2 com Link 2
5. Link 1 agora é inválido (token foi invalidado ao gerar o novo)
6. Maria usa Link 2 → redefine a senha normalmente
```

---

## 5. Possíveis erros comuns

### Erro: "Email não chega"

**Causas e soluções:**
1. `RESEND_API_KEY` não está configurada no `.env` — verificar e reiniciar o container
2. Email caiu no spam — verificar pasta de spam
3. Domínio do remetente não verificado no Resend — usar `onboarding@resend.dev` no plano grátis
4. Rate limit do Resend atingido (100 emails/dia grátis) — aguardar reset diário

**Como verificar se o backend tentou enviar:**
```bash
docker logs omniconnect-api 2>&1 | grep -i "email\|resend\|error" | tail -20
```

---

### Erro: "Link do email redireciona para a tela de Login"

**Causa:** O GoRouter inicia o `SplashScreen` brevemente ao carregar o app. Se o usuário não está autenticado, o SplashScreen redirecionava para login — sobrescrevendo a rota `/reset-password?token=...` do link antes de o GoRouter a processar.

**Solução aplicada:** O `SplashScreen` agora verifica a URL do navegador (`Uri.base.path`) antes de redirecionar. Se a URL for uma rota pública (`/reset-password`, `/forgot-password`, etc.), ele navega para essa rota e não vai para login.

**Verificar se o fix está ativo:**
```bash
grep -n "publicDeepLinks\|Uri.base" frontend/lib/screens/auth/splash_screen.dart
```
Deve retornar as linhas com a verificação de deep link.

**Pré-requisito:** o Flutter deve estar rodando com `--web-port 3000` correspondendo ao `FRONTEND_URL` no `.env`.

---

### Erro: "Token inválido" ao clicar no link

**Causas e soluções:**
1. Token expirou (+ de 60 minutos) → solicitar novo link
2. Token já foi usado → solicitar novo link
3. Usuário solicitou um segundo link → o primeiro foi invalidado; usar o mais recente
4. `FRONTEND_URL` ou `FRONTEND_RESET_PASSWORD_ROUTE` errado no `.env` → link aponta para rota errada

**Como verificar o link gerado:**
O link deve ter o formato:
```
{FRONTEND_URL}{FRONTEND_RESET_PASSWORD_ROUTE}?token={token_urlsafe}
```
Exemplo correto: `http://localhost:3000/reset-password?token=abc123xyz...`

---

### Erro: "Senha deve ter 8+ caracteres..."

**Causa:** A senha não atende os requisitos mínimos.

**Requisitos obrigatórios:**
- Mínimo **8 caracteres**
- Pelo menos **1 letra maiúscula** (A-Z)
- Pelo menos **1 letra minúscula** (a-z)
- Pelo menos **1 número** (0-9)
- Pelo menos **1 caractere especial** dos seguintes: `@$!%*?&_-`

**Exemplos:**
- ❌ `minhasenha` — sem maiúscula, número e especial
- ❌ `Senha123` — sem caractere especial
- ✅ `Senha123!` — atende todos os requisitos
- ✅ `OmniConnect2026@` — atende todos os requisitos

---

### Erro: "Erro de conexão" no app

**Causas e soluções:**
1. Backend não está rodando → executar `docker compose up` em `backend/`
2. Porta errada → verificar se está na porta 8000: `curl http://localhost:8000/health`
3. `FRONTEND_URL` apontando para URL diferente da que o Flutter Web usa

---

### Erro 429 Too Many Requests

**Causa:** Rate limit atingido (5 tentativas/hora por IP para forgot-password).

**Solução:** Aguardar que a janela de 1 hora se reinicie. Em desenvolvimento, reiniciar o container limpa os contadores.

---

## 6. Como simular envio de email em ambiente local (sem Resend real)

Se você não quer configurar o Resend, há duas opções:

### Opção A — Adicionar log temporário do token

Edite `backend/app/controllers/password_controller.py`, dentro do bloco `if result:`, antes do bloco `try` de envio de email:

```python
if result:
    token_raw, token_hash = result

    # ⚠️ APENAS PARA DESENVOLVIMENTO — REMOVER ANTES DE PRODUÇÃO
    import logging
    logging.warning(
        f"[DEV] Link de reset: "
        f"{settings.FRONTEND_URL}{settings.FRONTEND_RESET_PASSWORD_ROUTE}?token={token_raw}"
    )

    try:  # bloco de envio de email existente
        ...
```

Depois, faça a requisição de forgot-password e veja o link completo nos logs:
```bash
docker logs omniconnect-api 2>&1 | grep "\[DEV\]"
```

Copie o link do log e abra diretamente no navegador (com o Flutter rodando em `--web-port 3000`). **Remova o log temporário antes de commitar.**

### Opção B — Mailpit (servidor SMTP local)

Adicione ao `docker-compose.yml`:
```yaml
mailpit:
  image: axllent/mailpit
  ports:
    - "1025:1025"   # SMTP
    - "8025:8025"   # Web UI
```

Configure o `EmailService` para usar SMTP local ao invés de Resend. Acesse http://localhost:8025 para ver os emails capturados.

---

## 7. Arquivos importantes do sistema

```
backend/
├── app/
│   ├── models/password_reset_token.py      # Tabela de tokens
│   ├── repositories/password_reset_repository.py  # CRUD de tokens
│   ├── services/
│   │   ├── password_service.py             # Lógica principal
│   │   └── email_service.py               # Envio via Resend SDK v2
│   ├── controllers/password_controller.py  # Orquestra tudo
│   ├── routes/password.py                  # Endpoints HTTP
│   └── dtos/password_dto.py               # Validação de dados
└── .env                                    # Variáveis de ambiente

frontend/
└── lib/
    ├── screens/auth/
    │   ├── forgot_password_screen.dart     # Tela: digitar email
    │   ├── reset_password_screen.dart      # Tela: nova senha
    │   └── splash_screen.dart             # ⚠️ Contém fix de deep link
    ├── widgets/password_input_field.dart   # Campo de senha c/ indicador de força
    ├── providers/auth_provider.dart        # Gerencia estado do reset
    ├── services/auth_service.dart          # Chamadas HTTP
    └── routes/app_routes.dart             # Rota /reset-password?token=...
```

> **Nota — Resend SDK v2:** `email_service.py` usa a API estática do módulo resend v2 (`resend.api_key = ...` e `resend.Emails.send(...)`). A classe instanciável `Resend(api_key=...)` presente em versões anteriores (v0.x/v1.x) não existe mais na v2 e causaria `ImportError` silencioso seguido de falha no envio.

---

## 8. Diagrama de Sequência

```
Usuário          Flutter          Backend          Banco          Email
   │                │                │               │              │
   │ "Esqueci senha"│                │               │              │
   │────────────────▶               │               │              │
   │                │ POST           │               │              │
   │                │ /forgot-password────────────▶  │              │
   │                │                │ SELECT user   │              │
   │                │                │ ─────────────▶│              │
   │                │                │◀─────────────── user         │
   │                │                │ DELETE tokens │              │
   │                │                │ ─────────────▶│              │
   │                │                │ INSERT token  │              │
   │                │                │ ─────────────▶│              │
   │                │                │ Resend API ──────────────────▶
   │                │ 200 OK ◀───────│               │              │
   │ "Email enviado"│                │               │              │
   │◀───────────────│                │               │         email│
   │                │                                │         com  │
   │◀────────────────────────────────────────────────────────── link│
   │ clica no link  │                │               │              │
   │────────────────▶               │               │              │
   │                │ POST           │               │              │
   │ nova senha     │ /reset-password─────────────▶  │              │
   │                │                │ SELECT token  │              │
   │                │                │ ─────────────▶│              │
   │                │                │◀─────────────── token válido  │
   │                │                │ UPDATE user + │              │
   │                │                │ token used    │              │
   │                │                │ ─────────────▶│              │
   │                │ 200 OK ◀───────│               │              │
   │ "Senha alterada│                │               │              │
   │  → login"      │                │               │              │
   │◀───────────────│                │               │              │
```
