# 🏗️ Arquitetura Visual: Módulo de Pagamentos

---

## 📊 Camadas da Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                   CLIENTE (Flutter / Mobile)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Tela Planos  │  │   Checkout   │  │ Minha Assin. │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼──────────────────┼──────────────────┼──────────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────┐
│              FASTAPI ROUTES (payment.py)                    │
│  POST /admin/plans        GET /admin/plans                  │
│  PUT /admin/plans/:id     DELETE /admin/plans/:id           │
│  POST /subscriptions/checkout                               │
│  GET /subscriptions/current                                 │
│  POST /webhooks/asaas                                       │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│            SERVICE LAYER (payment_service.py)               │
│                                                             │
│  ┌─────────────────────┐  ┌────────────────────────┐       │
│  │  PlanService        │  │ SubscriptionService    │       │
│  ├─────────────────────┤  ├────────────────────────┤       │
│  │ create_plan()       │  │ create_checkout()      │       │
│  │ get_plan()          │  │ activate_subscription()│       │
│  │ list_plans()        │  │ get_subscription()     │       │
│  │ update_plan()       │  │ check_student_access() │       │
│  │ delete_plan()       │  │ cancel_subscription()  │       │
│  └─────────────────────┘  └────────────────────────┘       │
│                                                             │
│  ┌─────────────────────────────────────────────────┐       │
│  │       PaymentCronService (cron jobs)            │       │
│  ├─────────────────────────────────────────────────┤       │
│  │ expire_subscriptions()                          │       │
│  │ finalize_canceled()                             │       │
│  └─────────────────────────────────────────────────┘       │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│        REPOSITORY LAYER (payment_repository.py)             │
│                                                             │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │ PlanRepository       │  │SubscriptionRepositry│        │
│  ├──────────────────────┤  ├──────────────────────┤        │
│  │ create()             │  │ create()             │        │
│  │ find_by_id()         │  │ find_by_id()         │        │
│  │ find_by_admin()      │  │ find_by_external_id()│        │
│  │ update()             │  │ find_student_active()│        │
│  │ soft_delete()        │  │ activate()           │        │
│  │                      │  │ cancel_pending()     │        │
│  │                      │  │ expire_outdated()    │        │
│  │                      │  │ finalize_canceled()  │        │
│  └──────────────────────┘  └──────────────────────┘        │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│     MODELS (payment.py) + DTOs (payment_dtos.py)            │
│                                                             │
│  ┌──────────────┐           ┌──────────────────────┐       │
│  │   Plan       │           │  Subscription        │       │
│  ├──────────────┤           ├──────────────────────┤       │
│  │ id (UUID)    │           │ id (UUID)            │       │
│  │ admin_id     │           │ student_id           │       │
│  │ name         │           │ plan_id              │       │
│  │ price        │           │ admin_id             │       │
│  │ duration_mo  │           │ status               │       │
│  │ is_active    │           │ payment_method       │       │
│  │ created_at   │           │ external_payment_id  │       │
│  └──────────────┘           │ started_at           │       │
│                             │ expires_at           │       │
│  ┌─ Validadores ────────┐  │ created_at           │       │
│  │ CreatePlanDTO        │  └──────────────────────┘       │
│  │ UpdatePlanDTO        │                                  │
│  │ PlanResponseDTO      │  ┌─ Validadores ─────────────┐ │
│  └──────────────────────┘  │ CreateSubscriptionDTO      │ │
│                             │ SubscriptionResponseDTO    │ │
│                             │ SubscriptionDetailDTO      │ │
│                             │ CheckoutResponseDTO        │ │
│                             │ AsaasWebhookDTO            │ │
│                             └────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│              PostgreSQL Database                            │
│                                                             │
│  ┌──────────────────────────┐  ┌─────────────────────────┐ │
│  │   plans (table)          │  │ subscriptions (table)   │ │
│  ├──────────────────────────┤  ├─────────────────────────┤ │
│  │ PK: id (UUID)            │  │ PK: id (UUID)           │ │
│  │ FK: admin_id → users(id) │  │ FK: student_id → users  │ │
│  │ Fields: name, price,     │  │ FK: plan_id → plans     │ │
│  │ duration_months, ...     │  │ FK: admin_id → users    │ │
│  │                          │  │ Fields: status, method, │ │
│  │ Índices:                 │  │ external_id, dates...   │ │
│  │ - idx_plans_admin_id     │  │                         │ │
│  │ - idx_plans_is_active    │  │ Índices:                │ │
│  │ - idx_plans_created_at   │  │ - idx_subscriptions_... │ │
│  │                          │  │   (6 índices totais)    │ │
│  └──────────────────────────┘  └─────────────────────────┘ │
│                                                             │
│  Constraints:                                              │
│  - price > 0                                               │
│  - duration_months IN (1,3,6,12)                           │
│  - status IN (pending, active, expired, ...)               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Fluxo de Dados: Criar Plano

```
┌─────────────┐
│   Admin     │
│ (Flutter)   │
└──────┬──────┘
       │ POST /admin/plans
       │ {name, price, duration_months}
       │
       ▼
┌──────────────────────┐
│   FastAPI Route      │
│  validate auth       │
│  check role=admin    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   PlanService        │
│  create_plan()       │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ PlanRepository       │
│ create()             │
│ INSERT INTO plans    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   PostgreSQL         │
│   plans table        │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│   Response (200)     │
│  {id, name, price..} │
└──────────────────────┘
```

---

## 🔄 Fluxo de Dados: Checkout → Ativação

```
ALUNO                    BACKEND                 ASAAS
  │                        │                       │
  ├─ POST /checkout       │                       │
  │────────────────────────▶                       │
  │                        │                       │
  │  ┌────────────────────┐                       │
  │  │ 1. Criar           │                       │
  │  │ subscription       │                       │
  │  │ status=PENDING     │                       │
  │  └────────────────────┘                       │
  │  ┌────────────────────┐                       │
  │  │ 2. Gerar          │                       │
  │  │ checkout_url      │                       │
  │  └────────────────────┘                       │
  │                        │                       │
  │  ◀─ checkout_url ──────                       │
  │                        │                       │
  ├─ Abre URL ───────────────────────────────────▶│
  │  (redireciona)        │                       │
  │                        │                       │
  ├─ Entra cartão ───────────────────────────────▶│
  │                        │                       │
  │                        │  ◀─ processa ────────┤
  │                        │                       │
  │                        │  ◀─ webhook ─────────┤
  │                        │                       │
  │  ┌────────────────────┐                       │
  │  │ 3. POST            │                       │
  │  │ /webhooks/asaas    │                       │
  │  │ (payment_confirmed)│                       │
  │  └────────────────────┘                       │
  │  ┌────────────────────┐                       │
  │  │ 4. Ativar          │                       │
  │  │ subscription       │                       │
  │  │ status=ACTIVE      │                       │
  │  │ expires_at = NOW + │                       │
  │  │ duration_months    │                       │
  │  └────────────────────┘                       │
  │                        │                       │
  │  ◀─ GET /current ──────                       │
  │     (subscription ativa)                      │
  │                        │                       │
  └─ Acessa App ───────────────────────────────────
     (treino, dieta, IA, logbook)
```

---

## 🗂️ Estrutura de Pastas

```
backend/
├── app/
│   ├── models/
│   │   ├── __init__.py                  ← Imports: Plan, Subscription
│   │   ├── user.py                      (existente)
│   │   └── payment.py                   ✅ NOVO
│   │
│   ├── dtos/
│   │   ├── __init__.py                  ← Exports DTOs pagamentos
│   │   ├── user_dto.py                  (existente)
│   │   └── payment_dtos.py              ✅ NOVO
│   │
│   ├── repositories/
│   │   ├── __init__.py                  ← Exports repositories
│   │   └── payment_repository.py        ✅ NOVO
│   │
│   ├── services/
│   │   └── payment_service.py           ✅ NOVO
│   │
│   └── routes/
│       ├── __init__.py
│       ├── user.py                      (existente)
│       └── payment.py                   ✅ NOVO
│
├── migrations/
│   └── 004_create_payments_tables.sql   ✅ NOVO
│
├── tests/
│   └── test_payments.py                 ✅ NOVO
│
├── main.py                              ✅ ATUALIZADO (import payment)
└── requirements.txt                     (sem mudanças - tudo já incluído)

docs/
├── PRD_PAGAMENTOS_ASSINATURAS.md        ✅ NOVO
├── PLAN_IMPLEMENTACAO_PAGAMENTOS.md     ✅ NOVO
├── SETUP_PAGAMENTOS.md                  ✅ NOVO
├── TEST_PAYMENTS_API.md                 ✅ NOVO
├── PROXIMOS_PASSOS_PAGAMENTOS.md        ✅ NOVO
└── ARQUITETURA_PAGAMENTOS_VISUAL.md     ✅ NOVO (este arquivo)
```

---

## 📊 Dependências entre Componentes

```
┌─────────────────────┐
│   FastAPI Routes    │
└────────┬────────────┘
         │ usa
         ▼
┌─────────────────────┐
│   Services          │
└────────┬────────────┘
         │ usa
         ▼
┌─────────────────────┐
│   Repositories      │
└────────┬────────────┘
         │ usa
         ▼
┌─────────────────────┐
│   Models + DTOs     │
└────────┬────────────┘
         │ mapeia
         ▼
┌─────────────────────┐
│   PostgreSQL DB     │
└─────────────────────┘
```

---

## 🔐 Fluxo de Segurança

```
Requisição
   │
   ├─▶ [Auth Middleware]
   │   └─ Valida JWT token
   │      └─ Extrai user
   │
   ├─▶ [Route Handler]
   │   └─ Valida role (admin/student/personal)
   │      └─ Rejeita se role ≠ esperada
   │
   ├─▶ [Pydantic DTO]
   │   └─ Valida tipos + constraints
   │      ├─ price > 0 ✓
   │      ├─ duration_months IN (1,3,6,12) ✓
   │      └─ Rejeita dados inválidos
   │
   ├─▶ [Service]
   │   └─ Valida lógica de negócio
   │      └─ Rejeita operações ilegais
   │
   └─▶ [Repository]
       └─ Executa queries seguras
          └─ SQLAlchemy ORM (contra SQL injection)
```

---

## 📈 Escalabilidade

```
┌─────────────────────────────────────────┐
│  Multi-Tenant Support                   │
├─────────────────────────────────────────┤
│                                         │
│  Admin 1                                │
│  ├─ Plan A (10 alunos)                 │
│  ├─ Plan B (20 alunos)                 │
│  └─ Plan C (15 alunos)                 │
│                                         │
│  Admin 2                                │
│  ├─ Plan X (5 alunos)                  │
│  ├─ Plan Y (8 alunos)                  │
│  └─ Plan Z (12 alunos)                 │
│                                         │
│  → Cada admin vê seus próprios planos  │
│  → Queries filtradas por admin_id      │
│  → Sem acesso cruzado                   │
│                                         │
└─────────────────────────────────────────┘

Índices otimizam queries:
- idx_plans_admin_id → list by admin
- idx_subscriptions_student_id → find active sub
- idx_subscriptions_status → find expired
- Etc (6 índices no total)
```

---

## 🔄 Estado Máquina (Subscription)

```
                 ┌──────────────┐
                 │   PENDING    │
                 │(criada, não  │
                 │ ativada)     │
                 └───────┬──────┘
                         │ Webhook confirmado
                         ▼
                 ┌──────────────┐
                 │   ACTIVE     │
                 │(pagamento OK,│
                 │ acesso liberado)
                 └───┬───────┬──┘
                     │       │
        Cancelamento  │       │ Expiração
        manual        │       │ automática
                     ▼       ▼
            ┌────────────┐ ┌────────────┐
            │CANCELED_   │ │ EXPIRED    │
            │PENDING     │ │(sem acesso)│
            │(vence em X)│ └────────────┘
            └──────┬─────┘
                   │ Chega data
                   ▼
            ┌────────────┐
            │ CANCELED   │
            │(cancelado) │
            └────────────┘
```

---

## 📞 Integração com Asaas (Próxima Fase)

```
┌──────────────────────────────────────────┐
│  ASAAS PAYMENT GATEWAY (Futuro)         │
├──────────────────────────────────────────┤
│                                          │
│  1. Criar subscription no Asaas          │
│     POST /subscriptions                  │
│     {amount, customer, planId}           │
│     → Retorna checkout_url               │
│                                          │
│  2. Aluno paga no checkout              │
│     → Asaas processa pagamento           │
│                                          │
│  3. Webhook de confirmação               │
│     POST /webhooks/asaas                 │
│     {event, id, status, ...}             │
│                                          │
│  4. Backend ativa subscription           │
│     status = ACTIVE                      │
│     expires_at = now + duration_months   │
│                                          │
│  5. Aluno acessa app                     │
│                                          │
└──────────────────────────────────────────┘
```

---

**Este é o design final da Fase 1 do módulo de Pagamentos! 🎉**
