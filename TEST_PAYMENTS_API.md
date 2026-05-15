# 🧪 Teste Manual: API de Pagamentos

**Quando usar:** Após o Docker estar 100% pronto (dependências instaladas)

---

## 1️⃣ Verificar se API está rodando

```bash
curl http://localhost:8000/
```

**Resultado esperado:**
```json
{
  "status": "online",
  "message": "Servidor OmniConnect rodando com sucesso!",
  "docs": "Acesse http://localhost:8000/docs para ver a documentação interativa.",
  "version": "1.0.1"
}
```

---

## 2️⃣ Verificar Health Check de Pagamentos

```bash
curl http://localhost:8000/api/v1/payments/health
```

**Resultado esperado:**
```json
{
  "status": "ok",
  "service": "payments"
}
```

---

## 3️⃣ Acessar Swagger Interativo

Abra no navegador:
```
http://localhost:8000/docs
```

Procure por "payments" - devem listar 8 endpoints

---

## 4️⃣ Testar Endpoints (com Postman/Insomnia/curl)

### A. Criar Plano (Admin)

**Método:** POST  
**URL:** `http://localhost:8000/api/v1/admin/plans`

**Headers:**
```
Authorization: Bearer seu_jwt_token_admin
Content-Type: application/json
```

**Body:**
```json
{
  "name": "Premium",
  "description": "Treino + Dieta + IA",
  "price": 150.00,
  "duration_months": 1
}
```

**Resposta (200):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "admin_id": "admin-uuid",
  "name": "Premium",
  "price": 150.00,
  "currency": "BRL",
  "duration_months": 1,
  "is_active": true,
  "created_at": "2026-05-08T14:30:00Z",
  "updated_at": "2026-05-08T14:30:00Z"
}
```

---

### B. Listar Planos (Admin)

**Método:** GET  
**URL:** `http://localhost:8000/api/v1/admin/plans`

**Headers:**
```
Authorization: Bearer seu_jwt_token_admin
```

**Resposta (200):**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "admin_id": "admin-uuid",
    "name": "Premium",
    ...
  }
]
```

---

### C. Criar Checkout (Student)

**Método:** POST  
**URL:** `http://localhost:8000/api/v1/subscriptions/checkout`

**Headers:**
```
Authorization: Bearer seu_jwt_token_student
Content-Type: application/json
```

**Body:**
```json
{
  "plan_id": "550e8400-e29b-41d4-a716-446655440000",
  "payment_method": "credit_card"
}
```

**Resposta (200):**
```json
{
  "subscription_id": "sub-uuid",
  "checkout_url": "https://asaas.com/checkout/mock_sub-uuid",
  "external_payment_id": "pay_mock_sub-uuid",
  "status": "pending"
}
```

---

### D. Buscar Assinatura Atual (Student)

**Método:** GET  
**URL:** `http://localhost:8000/api/v1/subscriptions/current`

**Headers:**
```
Authorization: Bearer seu_jwt_token_student
```

**Resposta (200):**
```json
{
  "id": "sub-uuid",
  "student_id": "student-uuid",
  "plan_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "active",
  "payment_method": "credit_card",
  "started_at": "2026-05-08T14:30:00Z",
  "expires_at": "2026-06-08T14:30:00Z",
  "created_at": "2026-05-08T14:30:00Z",
  "plan": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Premium",
    "price": 150.00,
    ...
  }
}
```

---

### E. Simular Webhook Asaas

**Método:** POST  
**URL:** `http://localhost:8000/api/v1/webhooks/asaas`

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "event": "PAYMENT_CONFIRMED",
  "id": "pay_123456",
  "externalReference": "sub-uuid-da-subscription",
  "status": "CONFIRMED",
  "value": 150.00
}
```

**Resposta (200):**
```json
{
  "status": "success",
  "subscription_id": "sub-uuid-da-subscription",
  "message": "Assinatura ativada"
}
```

---

## 5️⃣ Rodar Testes Unitários

```bash
docker exec omniconnect-api pytest tests/test_payments.py -v
```

**Resultado esperado:**
```
test_payments.py::TestPlanRepository::test_create_plan PASSED
test_payments.py::TestPlanRepository::test_find_plan_by_id PASSED
test_payments.py::TestSubscriptionRepository::test_create_subscription PASSED
test_payments.py::TestSubscriptionService::test_create_checkout_service PASSED
...
======================== 10 passed in 3.21s ========================
```

---

## 6️⃣ Verificar Tabelas no BD

```bash
docker exec omniconnect-db psql -U omni_user -d omniconnect_db -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name"
```

**Deve listar:**
```
plans
subscriptions
(+ outras tabelas existentes)
```

---

## 🔑 Obter JWT Token (para testes)

Se precisar testar os endpoints autenticados:

```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "senha123"
  }'
```

Usar o `access_token` retornado no header `Authorization: Bearer TOKEN`

---

## ❌ Erros Comuns

| Erro | Causa | Solução |
|------|-------|---------|
| `404 Not Found` | Endpoint não existe | Verificar URL no Swagger |
| `401 Unauthorized` | Token inválido/ausente | Passar JWT válido no header |
| `400 Bad Request` | Dados inválidos | Verificar schema no Swagger |
| `500 Internal Server Error` | Erro no servidor | Ver `docker logs omniconnect-api` |
| `Table 'plans' does not exist` | Migrations não rodaram | Executar SQL manualmente |

---

## 📊 Checklist de Testes

- [ ] Health check retorna 200
- [ ] Criar plano retorna plano com UUID
- [ ] Listar planos retorna array
- [ ] Criar checkout retorna subscription PENDING
- [ ] Webhook muda status para ACTIVE
- [ ] Buscar assinatura retorna dados corretos
- [ ] Testes unitários passam com 80%+ cobertura
- [ ] Tabelas existem no BD

---

**Próximo:** Após confirmar que tudo funciona, integrar com Asaas real!
