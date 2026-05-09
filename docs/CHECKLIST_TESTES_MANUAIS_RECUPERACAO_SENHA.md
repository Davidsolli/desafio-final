# Checklist de Testes Manuais — Recuperação de Senha

**Projeto:** OmniConnect Fitness  
**Data:** 2026-05-09  
**Funcionalidade:** Sistema de Recuperação de Senha via Email  

---

## Pré-requisitos

- [ ] Docker containers rodando: `docker compose up` (dentro de `backend/`)
- [ ] Backend acessível em http://localhost:8000
- [ ] Flutter Web rodando **com porta fixa** — obrigatório para o link do email funcionar:
  ```bash
  flutter run -d chrome --web-port 3000
  ```
  > ⚠️ Sem `--web-port 3000`, o Flutter escolhe uma porta aleatória e o link do email (`localhost:3000/reset-password?token=...`) não carregará o app.
- [ ] App acessível em http://localhost:3000
- [ ] `.env` com `RESEND_API_KEY` válida (ou ver seção "Sem email real")
- [ ] Pelo menos um usuário cadastrado no sistema (ex: `william.s.marques1988@gmail.com` / `AlunoForte123!`)

---

## Cenário 1 — Fluxo Feliz Completo

**Objetivo:** Verificar que o fluxo completo funciona de ponta a ponta.

> **Pré-condição:** Flutter deve estar rodando com `flutter run -d chrome --web-port 3000` antes de clicar no link do email.

- [ ] Abrir app em http://localhost:3000 → tela de Login aparece
- [ ] Clicar "Esqueceu sua senha?" → ir para tela de recuperação
- [ ] Digitar email válido de um usuário cadastrado
- [ ] Clicar "Enviar Instruções"
- [ ] Ver spinner de carregamento durante a requisição
- [ ] Ver tela de sucesso: "Email Enviado!" com ícone verde
- [ ] Ver aviso de expiração: "⏰ O link expira em 60 minutos"
- [ ] Abrir caixa de entrada do email
- [ ] Email recebido com assunto "Recupere sua senha — OmniConnect Fitness"
- [ ] Email contém botão "Redefinir Minha Senha" com link válido
- [ ] Link do botão contém `?token=` com token alfanumérico longo
- [ ] Clicar no link → **Chrome abre `localhost:3000/reset-password?token=...` diretamente na tela "Redefinir Senha"** (não redireciona para login)
- [ ] Digitar nova senha forte (ex: `NovaSenha456!`)
- [ ] Indicador de força mostra barra verde e texto "Forte"
- [ ] Confirmar a mesma senha no campo de confirmação
- [ ] Badge verde "Senhas conferem" aparece
- [ ] Clicar "Redefinir Senha"
- [ ] Ver mensagem de sucesso (SnackBar verde)
- [ ] Ser redirecionado automaticamente para Login após 2 segundos
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
- [ ] Verificar no banco que nenhum token foi gerado para email inexistente

**Resultado esperado:** ✅ Sistema responde de forma idêntica para emails válidos e inválidos

---

## Cenário 3 — Token Expirado

**Objetivo:** Garantir que tokens expirados são rejeitados.

**Setup:** Gerar token válido, alterar `expires_at` no banco para o passado.
```sql
UPDATE password_reset_tokens
SET expires_at = NOW() - INTERVAL '1 hour'
WHERE used = false;
```

- [ ] Tentar acessar o link com token expirado
- [ ] Ver mensagem de erro na tela de reset
- [ ] Verificar mensagem clara: "Token inválido ou expirado"
- [ ] Campos de senha ficam habilitados (pode tentar outra vez com novo token)

**Resultado esperado:** ✅ Token expirado rejeitado com mensagem amigável

---

## Cenário 4 — Token Já Utilizado

**Objetivo:** Garantir que tokens são de uso único.

- [ ] Solicitar recuperação para um email
- [ ] Usar o link para redefinir a senha com sucesso
- [ ] Copiar o mesmo link e tentar acessá-lo novamente
- [ ] Ver mensagem de erro: "Token já foi utilizado"

**Resultado esperado:** ✅ Segundo uso do mesmo token é rejeitado

---

## Cenário 5 — Senhas Não Conferem

**Objetivo:** Validação de confirmação de senha funciona corretamente.

- [ ] Na tela de reset, digitar Nova Senha: `Forte123!`
- [ ] Digitar Confirmação: `Diferente456!`
- [ ] Badge vermelho "Senhas não conferem" aparece em tempo real
- [ ] Clicar "Redefinir Senha"
- [ ] Ver mensagem de erro: "As senhas não conferem. Os campos foram limpos."
- [ ] Verificar que ambos os campos de senha foram limpos automaticamente

**Resultado esperado:** ✅ Validação de confirmação funciona; campos são limpos ao errar

---

## Cenário 6 — Senha Fraca

**Objetivo:** Validação de força de senha impede senhas fracas.

- [ ] Na tela de reset, tentar cada uma das senhas abaixo:

| Senha | Esperado |
|-------|---------|
| `12345678` | Indicador: "Muito fraca" |
| `abcdefgh` | Indicador: "Muito fraca" |
| `Abcdefgh` | Indicador: "Fraca" |
| `Abcdefg1` | Indicador: "Média" |
| `Abc123!@` | Indicador: "Forte" |

- [ ] Tentar enviar com senha fraca (sem caractere especial)
- [ ] Ver mensagem de erro com requisitos

**Resultado esperado:** ✅ Indicador de força funciona; senhas fracas são rejeitadas

---

## Cenário 7 — Segundo Pedido Antes de Expirar (Renovação de Token)

**Objetivo:** Solicitar recuperação duas vezes invalida o primeiro token.

- [ ] Solicitar recuperação para um email → receber Email 1 com Link 1
- [ ] Solicitar recuperação de novo para o mesmo email → receber Email 2 com Link 2
- [ ] Tentar usar **Link 1** (antigo) → ver mensagem "Token inválido ou expirado"
- [ ] Usar **Link 2** (novo) → funcionamento normal da redefinição

**Resultado esperado:** ✅ Token anterior é invalidado; apenas o novo token funciona

---

## Cenário 8 — Token Inválido (Adulterado)

**Objetivo:** Tokens adulterados ou inventados são rejeitados.

- [ ] Acessar manualmente: `http://localhost:3000/reset-password?token=tokeninventado123`
- [ ] Ver mensagem de erro: "Token inválido"

**Resultado esperado:** ✅ Token inválido é rejeitado sem informações extras

---

## Cenário 9 — JWT Invalidado Após Reset de Senha

**Objetivo:** Após redefinir senha, sessões anteriores ficam inválidas.

- [ ] Fazer login e salvar o JWT recebido
- [ ] Em outra aba/sessão, solicitar reset e redefinir senha
- [ ] Tentar usar o JWT antigo para GET /api/v1/users/me
- [ ] Receber 401 Unauthorized (token_version mudou)

**Opcional (via curl):**
```bash
curl -H "Authorization: Bearer SEU_JWT_ANTIGO" http://localhost:8000/api/v1/users/me
# Espera: 401 {"detail": "Token inválido"}
```

**Resultado esperado:** ✅ JWT anterior é rejeitado após reset de senha

---

## Cenário 10 — Rate Limit

**Objetivo:** Rate limiting funciona para evitar abuso.

- [ ] Fazer 5 requisições seguidas para /forgot-password em menos de 1 hora
- [ ] Na 6ª requisição, receber erro 429 (Too Many Requests)

**Opcional (via curl):**
```bash
for i in {1..6}; do
  curl -s -X POST http://localhost:8000/api/v1/auth/forgot-password \
    -H "Content-Type: application/json" \
    -d '{"email": "teste@teste.com"}' | python3 -m json.tool
done
```

**Resultado esperado:** ✅ 5 primeiras OK; 6ª retorna 429

---

## Cenário 11 — Validação de Email na Entrada

**Objetivo:** Frontend valida formato do email antes de enviar.

- [ ] Tentar enviar campo vazio → mensagem "Por favor, insira seu email"
- [ ] Tentar enviar "não-é-um-email" → backend retorna 422

**Resultado esperado:** ✅ Campos vazios e emails inválidos são validados

---

## Testes de API (Regressão via Swagger)

Acesse http://localhost:8000/docs para testar via Swagger UI:

- [ ] `POST /api/v1/auth/forgot-password` com email válido → 200
- [ ] `POST /api/v1/auth/forgot-password` com email inválido → 422
- [ ] `POST /api/v1/auth/forgot-password` sem body → 422
- [ ] `POST /api/v1/auth/reset-password` com token válido + senha forte → 200
- [ ] `POST /api/v1/auth/reset-password` com token inválido → 400
- [ ] `POST /api/v1/auth/reset-password` com senhas não conferindo → 400 ou 422
- [ ] `POST /api/v1/auth/reset-password` com senha fraca → 400 ou 422

---

## Como Testar Sem Email Real

Se não tiver `RESEND_API_KEY` configurada, use uma das opções:

### Opção A — Ver token nos logs do Docker (requer log temporário)

Adicionar log temporário em `controllers/password_controller.py`, dentro do bloco `if result:`:
```python
# TEMPORÁRIO — REMOVER ANTES DE PRODUÇÃO
import logging
logging.warning(f"[DEBUG] Link de reset: {settings.FRONTEND_URL}{settings.FRONTEND_RESET_PASSWORD_ROUTE}?token={token_raw}")
```
Depois:
```bash
docker logs omniconnect-api 2>&1 | grep "\[DEBUG\]"
```
Copie o link do log e abra no navegador. **Remova o log antes de commitar.**

### Opção B — Consultar o banco diretamente
```bash
docker exec -it omniconnect-db psql -U omni_user -d omniconnect_db -c \
  "SELECT token_hash, expires_at, used FROM password_reset_tokens ORDER BY created_at DESC LIMIT 5;"
```
*(O token armazenado é o hash SHA256; você não conseguirá usar o hash diretamente — precisa do raw token que seria enviado por email)*

### Opção C — Construir o link manualmente a partir do hash no banco

1. Faça a requisição de forgot-password para o email desejado
2. Consulte o banco para ver que o token foi criado (hash apenas — não é o token real):
   ```bash
   docker exec omniconnect-db psql -U omni_user -d omniconnect_db -c \
     "SELECT id, expires_at, used, created_at FROM password_reset_tokens ORDER BY created_at DESC LIMIT 3;"
   ```
3. Para obter o token_raw, é necessário o log temporário (Opção A acima) — o banco armazena apenas o hash SHA256 e não é possível reverter para o token original

---

## Verificações Finais

- [ ] Nenhum token em texto plano armazenado no banco (apenas hash SHA256)
- [ ] Senha não é impressa em nenhum log
- [ ] Response de forgot-password nunca indica se email existe
- [ ] Email HTML renderiza corretamente (botão, link, aviso de expiração, ano correto)
- [ ] Token na URL do email é URL-safe (sem caracteres especiais problemáticos)
