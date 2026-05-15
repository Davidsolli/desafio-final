# 🚀 Setup Módulo de Pagamentos - FitLoop MVP V1

**Data:** 2026-05-08  
**Status:** ✅ Código implementado, aguardando testes e integração

---

## ✅ O que foi implementado

### Backend (FastAPI)

#### Models
- ✅ `Plan` - Planos de assinatura
- ✅ `Subscription` - Assinaturas dos alunos

#### DTOs (Pydantic)
- ✅ `CreatePlanDTO` - Criar plano
- ✅ `UpdatePlanDTO` - Atualizar plano
- ✅ `PlanResponseDTO` - Resposta plano
- ✅ `CreateSubscriptionDTO` - Criar assinatura
- ✅ `SubscriptionResponseDTO` - Resposta assinatura
- ✅ `SubscriptionDetailDTO` - Detalhes com plano
- ✅ `CheckoutResponseDTO` - Resposta checkout
- ✅ `AsaasWebhookDTO` - Webhook do Asaas

#### Repository Layer
- ✅ `PlanRepository` - CRUD de planos
- ✅ `SubscriptionRepository` - CRUD de assinaturas + cron jobs

#### Service Layer
- ✅ `PlanService` - Lógica de planos
- ✅ `SubscriptionService` - Lógica de assinaturas
- ✅ `PaymentCronService` - Jobs agendados

#### Endpoints (8 rotas)
- ✅ `POST /api/v1/admin/plans` - Criar plano
- ✅ `GET /api/v1/admin/plans` - Listar planos
- ✅ `GET /api/v1/admin/plans/{id}` - Buscar plano
- ✅ `PUT /api/v1/admin/plans/{id}` - Atualizar plano
- ✅ `DELETE /api/v1/admin/plans/{id}` - Deletar plano
- ✅ `POST /api/v1/subscriptions/checkout` - Criar checkout
- ✅ `GET /api/v1/subscriptions/current` - Minha assinatura
- ✅ `POST /api/v1/webhooks/asaas` - Webhook de pagamento

#### Testes
- ✅ 10+ testes unitários para repositories e services
- ✅ Cobertura de: criação, busca, ativação, expiração
- ✅ Arquivo: `backend/tests/test_payments.py`

---

## 📋 Arquivos Criados

```
backend/
├── app/
│   ├── models/
│   │   └── payment.py                    ← Models Plan + Subscription
│   ├── dtos/
│   │   └── payment_dtos.py              ← 8 DTOs com validação
│   ├── repositories/
│   │   └── payment_repository.py        ← Repository layer
│   ├── services/
│   │   └── payment_service.py           ← Service layer
│   └── routes/
│       └── payment.py                   ← 8 endpoints FastAPI
├── migrations/
│   └── 004_create_payments_tables.sql   ← Migration SQL
└── tests/
    └── test_payments.py                 ← 10+ testes

docs/
└── SETUP_PAGAMENTOS.md                  ← Este arquivo
```

---

## 🔄 Próximos Passos

### 1. Executar Migrations (D1 completo)

```bash
# Entrar no container
docker exec -it omniconnect-db psql -U omni_user -d omniconnect_db

# Ou copiar arquivo SQL e executar:
psql -U omni_user -d omniconnect_db -f backend/migrations/004_create_payments_tables.sql
```

**Verificar tabelas criadas:**
```sql
\dt plans
\dt subscriptions
```

### 2. Testar Endpoints (com Docker ativo)

```bash
# Health check do módulo
curl http://localhost:8000/api/v1/payments/health

# Swagger interativo
# Ir para: http://localhost:8000/docs
# Procurar por "payments"
```

### 3. Executar Testes

```bash
# Com Docker
docker exec omniconnect-api pytest tests/test_payments.py -v

# Localmente (Python venv ativo)
pytest tests/test_payments.py -v

# Com cobertura
pytest tests/test_payments.py -v --cov=app.services.payment_service --cov-report=html
```

---

## 🔌 Integrações Ainda Faltando

### Asaas (Gateway de Pagamento)

**O que precisa ser feito:**

1. **Registrar chaves de ambiente**
   ```bash
   # .env ou docker-compose.yml
   ASAAS_API_KEY=seu_api_key_asaas
   ASAAS_WEBHOOK_SECRET=seu_webhook_secret
   ASAAS_BASE_URL=https://sandbox.asaas.com  # ou prod
   ```

2. **Implementar chamadas HTTP para Asaas**
   ```python
   # Em payment_service.py, método create_checkout()
   # Usar httpx para fazer POST a https://asaas.com/api/v3/subscriptions
   ```

3. **Validar webhook com HMAC-SHA256**
   ```python
   # Em payment.py, endpoint /webhooks/asaas
   # Implementar validação de X-Signature header
   ```

### Frontend (Flutter)

**Arquivos ainda não criados:**

- `frontend/lib/screens/student/plans_screen.dart` - Tela de planos
- `frontend/lib/screens/student/my_subscription_screen.dart` - Minha assinatura
- `frontend/lib/services/payment_service.dart` - API client
- Integração com access gate (bloquear sem assinatura)

---

## 🧪 Cenários de Teste (Manual)

### Cenário 1: Criar Plano
```bash
curl -X POST http://localhost:8000/api/v1/admin/plans \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Premium",
    "description": "Treino + Dieta + IA",
    "price": 150.00,
    "duration_months": 1
  }'
```

### Cenário 2: Listar Planos
```bash
curl http://localhost:8000/api/v1/admin/plans \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Cenário 3: Criar Checkout
```bash
curl -X POST http://localhost:8000/api/v1/subscriptions/checkout \
  -H "Authorization: Bearer YOUR_STUDENT_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "plan_id": "UUID_DO_PLANO",
    "payment_method": "credit_card"
  }'
```

### Cenário 4: Webhook Simulado (Asaas)
```bash
curl -X POST http://localhost:8000/api/v1/webhooks/asaas \
  -H "Content-Type: application/json" \
  -d '{
    "event": "PAYMENT_CONFIRMED",
    "id": "pay_123456",
    "externalReference": "UUID_DA_SUBSCRIPTION",
    "status": "CONFIRMED",
    "value": 150.00
  }'
```

---

## 📊 Checklist Implementação

### ✅ Completo (Fase 1)
- [x] Models SQLAlchemy (Plan + Subscription)
- [x] DTOs Pydantic com validação
- [x] Repository layer (CRUD + queries)
- [x] Service layer (lógica de negócio)
- [x] Routes/Endpoints FastAPI
- [x] Testes unitários
- [x] Migrations SQL
- [x] Documentação

### ⏳ Em Progresso
- [ ] Integração real com Asaas
- [ ] Validação de webhook (HMAC-SHA256)
- [ ] Testes de integração E2E

### 📋 Futuro (Fase 2+)
- [ ] Telas Flutter (planos, checkout, assinatura)
- [ ] Access gate (bloquear sem subscription)
- [ ] Cron jobs (expiração automática)
- [ ] Notificações de vencimento
- [ ] Dashboard admin com relatórios

---

## 🔍 Troubleshooting

### Erro: "Module not found: app.models.payment"
**Solução:** Verifique se o `__init__.py` foi atualizado em `app/models/`

### Erro: "Table 'plans' does not exist"
**Solução:** Execute a migration SQL:
```bash
psql -U omni_user -d omniconnect_db -f backend/migrations/004_create_payments_tables.sql
```

### Erro: "401 Unauthorized" nos endpoints
**Solução:** Passe token JWT válido no header `Authorization: Bearer YOUR_TOKEN`

### Erro: "Webhook payload invalid"
**Solução:** Valide que `externalReference` é um UUID válido

---

## 📚 Referências

- PRD: [`docs/PRD_PAGAMENTOS_ASSINATURAS.md`](./PRD_PAGAMENTOS_ASSINATURAS.md)
- Plano: [`docs/PLAN_IMPLEMENTACAO_PAGAMENTOS.md`](./PLAN_IMPLEMENTACAO_PAGAMENTOS.md)
- API Docs: http://localhost:8000/docs (Swagger interativo)
- Asaas Docs: https://docs.asaas.com/

---

## 👤 Contato & Dúvidas

Se encontrar problemas:
1. Verifique os logs: `docker logs omniconnect-api`
2. Rode os testes: `pytest tests/test_payments.py -v`
3. Consulte o PRD para entender o fluxo

---

**Última atualização:** 2026-05-08  
**Próxima revisão:** Após testes E2E com Asaas
