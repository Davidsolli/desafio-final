# 🔧 Setup Webhook WhatsApp - OmniConnect Fitness

## ✅ Dados Configurados

```
Token Permanente: [Configurado no .env como WHATSAPP_TOKEN]
Phone Number ID: [Configurado no .env como WHATSAPP_PHONE_NUMBER_ID]
Verify Token: [Configurado no .env como WHATSAPP_VERIFY_TOKEN]
Webhook URL: https://<SEU_DOMINIO>/api/v1/webhooks/whatsapp
```

---

## 📋 Passo a Passo - Facebook Developer

### 1️⃣ Acessar Meta App Manager

1. Vá em https://developers.facebook.com/
2. Acesse seu **App ID** (OmniConnect ou similar)
3. Vá em **Configurações** → **Básico**

---

### 2️⃣ Configurar Webhook URL

1. No menu esquerdo, vá em **WhatsApp** → **Configuração**
2. Procure por **Webhook URL**
3. Clique em **Editar Callback URL**
4. Preencha:
   - **Callback URL:** `https://<SEU_DOMINIO>/api/v1/webhooks/whatsapp`
   - **Verify Token:** `<valor do WHATSAPP_VERIFY_TOKEN no .env>`

5. Clique em **Verificar e Salvar**

> ✅ O Meta enviará uma requisição GET para validar. Se tudo estiver certo, verá "Webhook verificado com sucesso!"

---

### 3️⃣ Inscrever nos Eventos de Webhook

Ainda em **WhatsApp** → **Configuração** → **Webhook**:

1. Em **Inscrever-se em eventos de webhook**, procure por **messages**
2. Clique em **Inscrever-se**

Agora o Meta enviará eventos quando mensagens chegarem.

---

### 4️⃣ Testar o Webhook

**Opção A: Pelo Meta - Usando o Teste de Webhook**

1. Na mesma página, procure por **Testar Webhook**
2. Clique em **Enviar Mensagem de Teste**

Se receber `200 OK`, está funcionando!

**Opção B: Send a Test Message (Recomendado)**

1. Va em **WhatsApp** → **Manage Phone Number**
2. Selecione seu número (<SEU_PHONE_NUMBER_ID>)
3. Procure por **Test Message** ou **Send Test Message**
4. Envie uma mensagem de teste

---

### 5️⃣ Monitorar Logs

Cada mensagem que chegar será logada. Para visualizar:

```bash
# SSH no servidor
ssh desafio02@lab.alphaedtech.org.br

# Ver logs em tempo real
pm2 logs omniconnect-api

# Ver logs histórico
pm2 logs omniconnect-api --lines 100
```

Você verá algo como:

```
📩 WEBHOOK RECEBIDO:
  {...dados da mensagem...}

📱 Mensagem recebida:
  De: 5511999999999
  Tipo: text
  Texto: Oi, quero me cadastrar!
  ID: wamid.xxxxx
```

---

## 🔒 Segurança Importante

⚠️ **Você compartilhou um token real!** Após testes, você DEVE:

1. Revogar o token no Facebook Developer
2. Gerar um novo token permanente
3. Atualizar no `.env`

**Como revogar:**
- Facebook Developer → Seu App → Configurações → Tokens
- Clique no token e selecione "Remover" ou "Revogar"

---

## 📝 Próximos Passos - Implementação

O webhook está recebendo mensagens! Agora você pode:

1. **Implementar pré-cadastro**
   - Arquivo: `backend/app/routes/webhooks.py`
   - Função: `receive_whatsapp_message()`

2. **Criar templates do WhatsApp**
   - Facebook Developer → WhatsApp → Templates
   - Exemplo: `pre_cadastro_inicio`, `confirmacao_cadastro`

3. **Responder ao usuário via WhatsApp API**
   - Usar o token para enviar mensagens de volta

---

## 🧪 Teste Rápido

Se quiser testar manualmente:

```bash
# SSH no servidor
ssh desafio02@lab.alphaedtech.org.br

# Testar webhook manualmente
curl -X GET "https://<SEU_DOMINIO>/api/v1/webhooks/whatsapp?hub.mode=subscribe&hub.challenge=123456789&hub.verify_token=<WHATSAPP_VERIFY_TOKEN>"

# Deve retornar: 123456789 (o hub.challenge)
```

---

## 📚 Documentação Oficial

- [Meta WhatsApp Cloud API](https://developers.facebook.com/docs/whatsapp/cloud-api)
- [Webhook Documentation](https://developers.facebook.com/docs/whatsapp/webhooks)
- [Send Messages](https://developers.facebook.com/docs/whatsapp/cloud-api/messages)
