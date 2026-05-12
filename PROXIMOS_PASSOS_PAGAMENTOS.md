# 🚀 Próximos Passos: Módulo de Pagamentos

**Status Atual:** ✅ Backend implementado + Docker rodando  
**Próximo:** Validar API + Criar telas Flutter

---

## ⏳ O que está acontecendo agora

1. **Docker:** Instalando dependências (torch, sentence-transformers, etc)
2. **API:** Será iniciada automaticamente em `http://localhost:8000`
3. **Banco:** Aguardando conexão para criar tabelas

---

## ✅ Assim que API ficar pronta

### 1. Criar Tabelas no Banco

```bash
docker exec omniconnect-db psql -U omni_user -d omniconnect_db << 'EOF'
CREATE TABLE IF NOT EXISTS plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    price NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'BRL',
    duration_months INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    CONSTRAINT price_positive CHECK (price > 0),
    CONSTRAINT duration_valid CHECK (duration_months IN (1, 3, 6, 12))
);

CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES plans(id),
    admin_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(20) DEFAULT 'pending',
    payment_method VARCHAR(20),
    external_payment_id VARCHAR(100) UNIQUE,
    started_at TIMESTAMP,
    expires_at TIMESTAMP,
    canceled_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT status_valid CHECK (status IN ('pending', 'active', 'expired', 'canceled_pending', 'canceled'))
);

CREATE INDEX IF NOT EXISTS idx_plans_admin_id ON plans(admin_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_student_id ON subscriptions(student_id);
EOF
```

### 2. Verificar Tabelas Criadas

```bash
docker exec omniconnect-db psql -U omni_user -d omniconnect_db -c "SELECT table_name FROM information_schema.tables WHERE table_name IN ('plans', 'subscriptions')"
```

### 3. Testar Health Check

```bash
curl http://localhost:8000/api/v1/payments/health
```

**Esperado:**
```json
{"status":"ok","service":"payments"}
```

### 4. Rodar Testes

```bash
docker exec omniconnect-api pytest tests/test_payments.py -v --cov=app.services.payment_service
```

**Esperado:** 10+ testes passando com 80%+ cobertura

### 5. Acessar Swagger

Abra: `http://localhost:8000/docs`

Procure por "payments" e teste os endpoints

---

## 📋 Checklist Hoje

- [ ] API iniciou com sucesso
- [ ] Tabelas `plans` e `subscriptions` criadas
- [ ] Health check retorna 200 OK
- [ ] Testes unitários passam
- [ ] Endpoints testáveis no Swagger
- [ ] Git commit com tudo finalizado

---

## 🎯 Amanhã - D5 (Frontend)

Depois que validarmos backend, começar:

### Telas Flutter Necessárias

1. **PlansScreen** - Listar planos disponíveis
   ```dart
   GET /api/v1/admin/plans → lista
   POST /api/v1/subscriptions/checkout → contrata
   ```

2. **MySubscriptionScreen** - Minha assinatura ativa
   ```dart
   GET /api/v1/subscriptions/current → exibe
   ```

3. **PaymentService** - API client
   ```dart
   - getAvailablePlans()
   - createCheckout(planId, method)
   - getCurrentSubscription()
   ```

4. **Access Gate** - No shell do aluno
   ```dart
   if (hasActiveSubscription) 
     → show app (treino, dieta, IA, logbook)
   else 
     → show PlansScreen (contratar)
   ```

---

## 📚 Referências

| Doc | Conteúdo |
|-----|----------|
| `PRD_PAGAMENTOS_ASSINATURAS.md` | Requisitos completos |
| `PLAN_IMPLEMENTACAO_PAGAMENTOS.md` | Timeline + código |
| `SETUP_PAGAMENTOS.md` | Setup + troubleshooting |
| `TEST_PAYMENTS_API.md` | Como testar endpoints |
| `IMPLEMENTACAO_PAGAMENTOS_SUMMARY.md` | Resumo visual |

---

## 🔗 Links Úteis

- **Swagger:** http://localhost:8000/docs
- **Health Check:** http://localhost:8000/
- **Asaas Sandbox:** https://sandbox.asaas.com
- **Asaas Docs:** https://docs.asaas.com

---

## ❌ Troubleshooting Rápido

### "API não responde"
```bash
docker logs omniconnect-api | tail -50
```

### "Table does not exist"
```bash
# Criar tabelas manualmente (ver seção acima)
```

### "Teste falha com 401"
```bash
# Precisa JWT token válido
# Obter via POST /auth/login
```

### "Webpack error"
```bash
# Reconstruir: docker compose up --build
```

---

## 📈 Roadmap

### MVP V1 (Fase 1) ✅
- [x] Backend (models, DTOs, services, endpoints)
- [x] Migrations SQL
- [x] Testes unitários
- [x] Documentação

### MVP V1 (Fase 2) 🔄 (Esta semana)
- [ ] Frontend Flutter (telas)
- [ ] Testar E2E (checkout até ativação)
- [ ] Integração Asaas real

### MVP V2 (Futuro)
- [ ] Rastreamento de entregáveis
- [ ] Cron jobs em produção
- [ ] Dashboard admin
- [ ] Relatórios

---

## 💬 Resumo

**O que foi feito:**
- ✅ Backend completo (1,300 linhas)
- ✅ 8 endpoints FastAPI
- ✅ 10+ testes unitários
- ✅ Documentação detalhada
- ✅ Docker rodando

**O que fazer agora:**
- ⏳ Validar endpoints (Swagger)
- ⏳ Criar tabelas no BD
- ⏳ Rodar testes
- ⏳ Frontend (D5)

**Timeline:**
- Hoje: Backend + Validação
- Amanhã: Frontend Flutter
- Dia depois: E2E + Asaas real

---

**Próxima ação:** Aguardar notificação do Monitor que API está pronta! 🚀
