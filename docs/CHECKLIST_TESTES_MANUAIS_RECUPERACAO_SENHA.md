# Checklist de Testes Manuais — Recuperação de Senha

**Projeto:** OmniConnect Fitness  
**Data:** 2026-05-10  
**Funcionalidade:** Sistema de Recuperação de Senha via Email  

---

## Pré-requisitos

- [ ] Docker containers rodando: `docker compose up` (dentro de `backend/`)
- [ ] Backend acessível em http://localhost:8000
- [ ] Flutter Web rodando com **porta fixa** correspondente ao `FRONTEND_URL` no `.env`:

  **Chrome (recomendado):**
  ```bash
  cd frontend
  flutter run -d chrome --web-port 3000
  ```

  **Edge:**
  ```bash
  flutter run -d edge --web-port 3000
  ```

  **Qualquer navegador (abre servidor sem abrir o browser):**
  ```bash
  flutter run -d web-server --web-port 3000
  # → abrir http://localhost:3000 manualmente em qualquer browser
  ```

  > ⚠️ Sem `--web-port 3000`, o Flutter escolhe uma porta aleatória e o link do email (`localhost:3000/reset-password?token=...`) não carregará o app.  
  > Para outros targets (Android, iOS, desktop), veja o [TUTORIAL_RECUPERACAO_SENHA.md](./TUTORIAL_RECUPERACAO_SENHA.md#5-opções-de-execução-do-flutter).

- [ ] App acessível em http://localhost:3000
- [ ] `.env` com `RESEND_API_KEY` válida (ou ver seção "Sem email real" abaixo)
- [ ] Pelo menos um usuário cadastrado no sistema (ex: `usuario@exemplo.com` / `SenhaForte123!`)

---

## Cenário 1 — Fluxo Feliz Completo

**Objetivo:** Verificar que o fluxo completo funciona de ponta a ponta.

> **Pré-condição:** Flutter deve estar rodando com `flutter run -d chrome --web-port 3000` antes de clicar no link do email.

- [ ] Abrir app em http://localhost:3000 → tela de Login aparece
- [ ] Clicar "Esqueceu sua senha?" → ir para tela de recuperação (`/forgot-password`)
- [ ] Digitar email válido de um usuário cadastrado
- [ ] Clicar "Enviar Instruções"
- [ ] Ver tela de sucesso: "Email Enviado!" com orientação de checar a caixa de entrada
- [ ] Abrir caixa de entrada do email
- [ ] Email recebido com assunto "Recupere sua senha — OmniConnect Fitness"
- [ ] Email contém botão "Redefinir Minha Senha" com link válido
- [ ] Link do botão contém `?token=` com token alfanumérico longo
- [ ] Clicar no link → **browser abre `localhost:3000/reset-password?token=...` diretamente na tela "Nova Senha"** (não redireciona para login)
- [ ] Tela mostra dois campos: "Nova Senha" e "Confirmar Nova Senha"
- [ ] Tela mostra caixa de requisitos: 8 caracteres, maiúscula, minúscula, número, especial
- [ ] Digitar nova senha forte (ex: `NovaSenha456!`) em ambos os campos
- [ ] Clicar "Redefinir Senha"
- [ ] Ser redirecionado para tela de Login com SnackBar verde: "Senha redefinida com sucesso! Faça login com sua nova senha."
- [ ] Fazer login com a **nova** senha → login bem-sucedido
- [ ] Tentar login com a **senha antiga** → falha com "Credenciais inválidas"

**Resultado esperado:** ✅ Fluxo completo funciona sem erros

---

## Cenário 2 — Email Não Cadastrado (Anti-enumeração)

**Objetivo:** Garantir que o sistema não revela se um email existe.

- [ ] Na tela de recuperação, digitar um email que não existe no sistema
- [ ] Clicar "Enviar Instruções"
- [ ] Ver a **mesma tela de sucesso** que para emails válidos
- [ ] Verificar que **nenhum email** foi enviado para o endereço
- [ ] Verificar no banco que nenhum token foi gerado para email inexistente:
  ```bash
  docker exec omniconnect-db psql -U omni_user -d omniconnect_db -c \
    "SELECT count(*) FROM password_reset_tokens WHERE created_at > NOW() - INTERVAL '5 minutes';"
  ```

**Resultado esperado:** ✅ Sistema responde de forma idêntica para emails válidos e inválidos

---

## Cenário 3 — Token Expirado

**Objetivo:** Garantir que tokens expirados são rejeitados.

**Setup:** Gerar token válido, alterar `expires_at` no banco para o passado:
```sql
-- Conectar ao banco:
docker exec -it omniconnect-db psql -U omni_user -d omniconnect_db

-- Expirar todos os tokens ativos:
UPDATE password_reset_tokens
SET expires_at = NOW() - INTERVAL '1 hour'
WHERE used = false;
```

- [ ] Tentar usar o link com token expirado
- [ ] Ver SnackBar de erro na tela de reset: "Token expirado. Solicite um novo link de recuperação"
- [ ] Campos de senha são limpos automaticamente

**Resultado esperado:** ✅ Token expirado rejeitado com mensagem amigável

---

## Cenário 4 — Token Já Utilizado

**Objetivo:** Garantir que tokens são de uso único.

- [ ] Solicitar recuperação para um email
- [ ] Usar o link para redefinir a senha com sucesso
- [ ] Copiar o mesmo link e acessá-lo novamente no browser
- [ ] Ver SnackBar de erro: "Este token já foi utilizado"

**Resultado esperado:** ✅ Segundo uso do mesmo token é rejeitado

---

## Cenário 5 — Senhas Não Conferem

**Objetivo:** Validação de confirmação de senha funciona corretamente.

- [ ] Na tela de reset, digitar Nova Senha: `Forte123!`
- [ ] Digitar Confirmação: `Diferente456!`
- [ ] Clicar "Redefinir Senha"
- [ ] Ver SnackBar de erro: "As senhas não conferem"
- [ ] Verificar que ambos os campos de senha foram limpos automaticamente

**Resultado esperado:** ✅ Validação de confirmação funciona; campos são limpos ao errar

---

## Cenário 6 — Senha Fraca

**Objetivo:** Validação de força de senha impede senhas fracas.

- [ ] Na tela de reset, digitar a mesma senha fraca em ambos os campos e clicar "Redefinir Senha":

| Senha (ambos campos) | Esperado |
|----------------------|---------|
| `12345678` | SnackBar com requisitos da senha |
| `Abcdefgh` | SnackBar com requisitos da senha (falta número e especial) |
| `Abcdefg1` | SnackBar com requisitos da senha (falta especial) |
| `Abc123!@` | Sucesso — atende todos os requisitos |

- [ ] Verificar que a mensagem de erro do backend é exibida no SnackBar vermelho
- [ ] Verificar que após erro, os campos são limpos

**Resultado esperado:** ✅ Senhas fracas são rejeitadas com mensagem clara

---

## Cenário 7 — Segundo Pedido Antes de Expirar (Renovação de Token)

**Objetivo:** Solicitar recuperação duas vezes invalida o primeiro token.

- [ ] Solicitar recuperação para um email → receber Email 1 com Link 1
- [ ] Solicitar recuperação de novo para o mesmo email → receber Email 2 com Link 2
- [ ] Tentar usar **Link 1** (antigo) → SnackBar: "Token inválido ou expirado"
- [ ] Usar **Link 2** (novo) → funcionamento normal da redefinição

**Resultado esperado:** ✅ Token anterior é invalidado; apenas o novo token funciona

---

## Cenário 8 — Token Inválido (Adulterado)

**Objetivo:** Tokens adulterados ou inventados são rejeitados.

- [ ] Acessar manualmente: `http://localhost:3000/reset-password?token=tokeninventado123`
- [ ] Ver SnackBar de erro: "Token inválido ou expirado"

**Resultado esperado:** ✅ Token inválido é rejeitado sem informações extras

---

## Cenário 9 — JWT Invalidado Após Reset de Senha

**Objetivo:** Após redefinir senha, sessões anteriores ficam inválidas.

- [ ] Fazer login e copiar o JWT recebido (via DevTools → Network → response do `/auth/login`)
- [ ] Em outra aba/sessão, solicitar reset e redefinir a senha
- [ ] Tentar usar o JWT antigo para `GET /api/v1/users/me`
- [ ] Receber 401 Unauthorized (`token_version` mudou)

**Via curl:**
```bash
curl -H "Authorization: Bearer SEU_JWT_ANTIGO" http://localhost:8000/api/v1/users/me
# Espera: 401 {"detail": "Could not validate credentials"}
```

**Resultado esperado:** ✅ JWT anterior é rejeitado após reset de senha

---

## Cenário 10 — Rate Limit

**Objetivo:** Rate limiting funciona para evitar abuso.

- [ ] Fazer 5 requisições seguidas para `/forgot-password` em menos de 1 hora
- [ ] Na 6ª requisição, receber erro 429 (Too Many Requests)

**Via curl (mais rápido que pelo app):**
```bash
for i in {1..6}; do
  echo "--- Requisição $i ---"
  curl -s -X POST http://localhost:8000/api/v1/auth/forgot-password \
    -H "Content-Type: application/json" \
    -d '{"email": "teste@teste.com"}'
  echo ""
done
```

**Reset dos contadores em dev:**
```bash
docker restart omniconnect-api
```

**Resultado esperado:** ✅ 5 primeiras OK; 6ª retorna 429

---

## Cenário 11 — Validação de Email na Entrada

**Objetivo:** Frontend valida formato do email antes de enviar.

- [ ] Tentar enviar campo vazio → SnackBar "Por favor, insira seu email"
- [ ] Tentar enviar "não-é-um-email" → SnackBar de erro (backend retorna 422)

**Resultado esperado:** ✅ Campos vazios e emails inválidos são validados

---

## Testes de API (Regressão via Swagger)

Acesse http://localhost:8000/docs para testar via Swagger UI:

- [ ] `POST /api/v1/auth/forgot-password` com email válido → 200
- [ ] `POST /api/v1/auth/forgot-password` com email inválido (sem @) → 422
- [ ] `POST /api/v1/auth/forgot-password` sem body → 422
- [ ] `POST /api/v1/auth/reset-password` com token válido + senha forte → 200
- [ ] `POST /api/v1/auth/reset-password` com token inválido → 400
- [ ] `POST /api/v1/auth/reset-password` com senhas não conferindo → 400
- [ ] `POST /api/v1/auth/reset-password` com senha fraca → 400
- [ ] `POST /api/v1/auth/reset-password` sem body → 422

---

## Como Testar Sem Email Real

Se não tiver `RESEND_API_KEY` configurada:

### Opção A — Log temporário do token nos logs do container

Adicionar log temporário em `backend/app/services/password_service.py`, no método `request_reset`, antes do bloco `try` de envio:

```python
# TEMPORÁRIO — REMOVER ANTES DE PRODUÇÃO
logger.warning("[DEV] Link de reset: %s%s?token=%s",
               settings.FRONTEND_URL, settings.FRONTEND_RESET_PASSWORD_ROUTE, plain_token)
```

Copiar o arquivo para dentro do container e reiniciar:
```bash
docker cp backend/app/services/password_service.py omniconnect-api:/app/app/services/password_service.py
docker restart omniconnect-api
```

Após fazer a requisição de forgot-password:
```bash
docker logs omniconnect-api 2>&1 | grep "\[DEV\]"
```

Copie o link, abra no navegador (com Flutter rodando em `--web-port 3000`). **Remova o log antes de commitar.**

### Opção B — Consultar o banco para confirmar criação do token

O banco só armazena o hash SHA256 — não é possível usar o hash como token. Use para confirmar que o token foi criado:

```bash
docker exec omniconnect-db psql -U omni_user -d omniconnect_db -c \
  "SELECT id, expires_at, used, created_at FROM password_reset_tokens ORDER BY created_at DESC LIMIT 5;"
```

Para obter o token raw (para teste), combine com a Opção A acima.

---

## Verificações Finais de Segurança

- [ ] Nenhum token em texto plano armazenado no banco (apenas hash SHA256)
- [ ] Senha não é impressa em nenhum log
- [ ] Response de `forgot-password` nunca indica se email existe (mesmo body para válidos e inválidos)
- [ ] Email HTML renderiza corretamente no cliente de email (botão, link, aviso de expiração)
- [ ] Token na URL do email é URL-safe (sem caracteres problemáticos como `+`, `/`)
- [ ] Após reset, login com senha antiga falha
- [ ] Após reset, JWT anterior retorna 401
