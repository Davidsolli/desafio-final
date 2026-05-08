# PRD: Módulo de Pagamentos e Assinaturas - FitLoop (MVP v1)

**Versão:** 1.1 (MVP Simplificado)  
**Data:** 2026-05-07  
**Status:** 🟢 Pronto para Desenvolvimento  
**Prioridade:** 🔴 CRÍTICA (MVP)  
**Stack:** FastAPI (Python) + PostgreSQL + Asaas/Mercado Pago

---

## 📋 Sumário Executivo

O módulo de Pagamentos e Assinaturas estabelece o fluxo financeiro do FitLoop V1, permitindo que **Admins (Academias/Personais Autônomos)** criem planos de serviço e cobrem alunos.

**Princípio Central:** Pagamento Aprovado = Acesso Liberado ao App (Gatekeeper de Acesso).

**Foco MVP:** Simplicidade extrema. O sistema libera acesso ao software após confirmação de pagamento. Gestão de entregáveis físicos (avaliações, encontros) fica responsabilidade do Personal no dia a dia (WhatsApp, Google Calendar, etc).

---

## 🎯 Objetivos (MVP V1)

- ✅ Permitir Admin criar/editar planos com informações básicas (nome, preço, duração)
- ✅ Processar pagamentos via gateway (Pix + Cartão com renovação automática)
- ✅ Liberar acesso universal ao app (treino, dieta, IA) para clientes com assinatura ACTIVE
- ✅ Gerenciar ciclo de vida: PENDING → ACTIVE → EXPIRED/CANCELED
- ✅ Suportar Multi-Tenant (Academias e Personals Autônomos)
- ✅ Exibir plano contratado no perfil do aluno (info para o Personal)

**Fora do MVP V1:**
- ❌ Rastreamento de entregáveis físicos (avaliações, encontros)
- ❌ Histórico de atendimentos (attendance records)
- ❌ Telas de "dar baixa" em serviços
- ❌ Gestão de agenda/agendamentos

---

## 👥 Stakeholders

| Ator | Responsabilidade |
|------|-----------------|
| **Admin (Academia/Personal)** | Criar planos, visualizar pagamentos, gerir alunos |
| **Personal Trainer** | Marcar atendimentos, consumir entregáveis |
| **Cliente (Aluno)** | Contratar plano, usar app, pagar assinatura |
| **Backend (Node.js)** | Processar webhooks, gerenciar BD, aplicar regras |
| **Gateway (Asaas/MercadoPago)** | Processar pagamentos, enviar webhooks |

---

## 🏗️ Arquitetura & Diretriz Principal (MVP V1)

### A. Princípio: Gatekeeper de Acesso

```
┌─────────────────────────────────────────────┐
│  ACESSO AO SOFTWARE (100% Universal)        │
├─────────────────────────────────────────────┤
│ ✅ Visualização de Treinos                  │
│ ✅ Módulo de Dieta                          │
│ ✅ Acompanhamento de Progresso              │
│ ✅ Chatbot IA                               │
│ ✅ Logbook de Exercícios                    │
│                                             │
│ ⚠️ LIBERADO APENAS SE:                      │
│    subscription.status == "ACTIVE"          │
│    AND expires_at > CURRENT_TIMESTAMP       │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  INFORMAÇÕES DO PLANO (No Perfil do Aluno) │
├─────────────────────────────────────────────┤
│ • Nome do Plano                             │
│ • Preço Mensal                              │
│ • Data de Contratação                       │
│ • Data de Expiração                         │
│ • Próxima Renovação                         │
│                                             │
│ (Personal vê isto e sabe o que entregar)    │
└─────────────────────────────────────────────┘
```

**Simplificação:** Nenhuma tela fica bloqueada. O acesso é binário: ACTIVE ou não. Personal gerencia entregáveis no WhatsApp/Google Calendar.

---

## 📊 Modelos de Dados (MVP V1)

### 1. Tabela `plans` (Planos disponíveis)

```sql
CREATE TABLE plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Identificação
    name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Financeiro
    price DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'BRL',
    
    -- Duração
    duration_months INT NOT NULL, -- 1, 3, 6, 12
    
    -- Metadata
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP, -- Soft delete
    
    CONSTRAINT price_positive CHECK (price > 0),
    CONSTRAINT duration_valid CHECK (duration_months IN (1, 3, 6, 12))
);

CREATE INDEX idx_plans_admin_id ON plans(admin_id);
CREATE INDEX idx_plans_is_active ON plans(is_active);
```

**Nota:** Sem campos de entregáveis. Admin cria um plano simples (nome, preço, duração). Personal gerencia o que entregar externamente.

---

### 2. Tabela `subscriptions` (Assinaturas dos alunos)

```sql
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES plans(id),
    admin_id UUID NOT NULL REFERENCES users(id), -- Quem criou o plano
    
    -- Status & Lifecycle
    status VARCHAR(20) NOT NULL, -- 'pending', 'active', 'expired', 'canceled_pending', 'canceled'
    
    -- Pagamento
    payment_method VARCHAR(20), -- 'pix', 'credit_card'
    external_payment_id VARCHAR(100) UNIQUE, -- ID do gateway (Asaas/MercadoPago)
    
    -- Datas
    started_at TIMESTAMP, -- Quando começou (após webhook de confirmação)
    expires_at TIMESTAMP, -- Quando expira
    canceled_at TIMESTAMP, -- Quando foi cancelado (se aplicável)
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT status_valid CHECK (status IN ('pending', 'active', 'expired', 'canceled_pending', 'canceled'))
);

CREATE INDEX idx_subscriptions_student_id ON subscriptions(student_id);
CREATE INDEX idx_subscriptions_admin_id ON subscriptions(admin_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_expires_at ON subscriptions(expires_at);
```

**Nota:** Simplificado. Sem entregáveis ou histórico de atendimentos. Apenas controla status de acesso.

---

## 🔄 Fluxos (MVP V1)

### A. Fluxo de Contratação (Aluno)

```
1. Aluno visualiza planos disponíveis na tela "Planos"
   ↓
2. Seleciona um plano e clica "Contratar Agora"
   ↓
3. Sistema redireciona para Gateway (Asaas/MercadoPago) - Checkout
   ├─ Paga com Cartão → Cobra recorrente todo mês
   └─ Paga com Pix → Único (lembretes 3 dias antes)
   ↓
4. Gateway retorna callback (webhook) → Backend processa
   ↓
5. Status da assinatura muda para ACTIVE
   ├─ started_at = CURRENT_TIMESTAMP
   ├─ expires_at = started_at + duration_months
   └─ ❌ SEM criação de entregáveis
   ↓
6. Aluno recebe confirmação via email
   ↓
7. Acesso ao app é liberado (treino, dieta, IA, logbook)
   ↓
8. Personal vê no perfil do aluno: "Plano: Premium R$ 150/mês até 07/06/2026"
```

---

### B. Máquina de Estados da Assinatura

```
                    ┌──────────────┐
                    │   PENDING    │
                    │ (Aguardando  │
                    │  pagamento)  │
                    └───────┬──────┘
                            │ Webhook confirmado
                            ▼
                    ┌──────────────┐
                    │    ACTIVE    │
                    │  (Acesso OK) │
                    └───┬──────┬───┘
                        │      │
        Aluno cancela   │      │ Data de expiração
        manualmente     │      │ atingida
                        ▼      ▼
            ┌──────────────────┐     ┌──────────────┐
            │ CANCELED_PENDING │     │   EXPIRED    │
            │ (Vence em X)     │     │  (Sem acesso)│
            └──────────────────┘     └──────────────┘
                    │
                    │ Chega data de expiração
                    ▼
            ┌──────────────┐
            │  CANCELED    │
            │(Sem acesso)  │
            └──────────────┘
```

**Estados:**
- `PENDING`: Criada, pagamento não confirmado. Acesso bloqueado.
- `ACTIVE`: Pagamento confirmado. Acesso total ao app.
- `CANCELED_PENDING`: Aluno cancelou, mas ainda acessa até expire_at.
- `EXPIRED`: Data de expiração atingida. Acesso bloqueado.
- `CANCELED`: Cancelamento finalizado. Acesso bloqueado.

---

### C. Gestão de Entregáveis (Fora do MVP V1)

**Personal gerencia entregáveis NO WHATSAPP/GOOGLE CALENDAR:**

```
Exemplo:
- Aluno contrata plano "Premium: 3 aval/mês"
- Personal vê no app: "Premium até 07/06/2026"
- Personal anotaem seu Google Calendar/WhatsApp que precisa fazer
  3 avaliações com este aluno durante o mês
- Nada é rastreado no app (por enquanto)
```

✅ **Benefício:** Zero complexidade. Personal gerencia como sempre fez.

---

## 🔌 Integração com Gateway de Pagamento

### Suportados

1. **Asaas** (Recomendado para Brasil)
   - Pix, Cartão, Boleto
   - Webhooks confiáveis
   - Split de pagamentos (futuro)

2. **Mercado Pago**
   - Pix, Cartão
   - API madura
   - Bom suporte ao Brasil

### Fluxo Webhook

```
┌─────────────────────────────────────────────┐
│  Cliente faz pagamento no Gateway           │
└────────────────────┬────────────────────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │ Gateway processa pgtx  │
        └────────────┬───────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ POST /webhooks/payment         │
        │ {                              │
        │   event: "payment.confirmed"   │
        │   external_payment_id: "xxx"   │
        │   status: "approved"           │
        │   amount: 99.90                │
        │ }                              │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ Backend valida assinatura      │
        │ da webhook (segurança)         │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ Busca subscription por         │
        │ external_payment_id            │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ Atualiza status para ACTIVE    │
        │ + started_at / expires_at      │
        │ + Cria deliverables            │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ Envia confirmação via          │
        │ email/WhatsApp ao aluno        │
        └────────────────────────────────┘
```

---

## 📱 API Endpoints (FastAPI - Python)

### Admin: Gestão de Planos

```python
# POST /api/v1/admin/plans
# Criar plano
POST /api/v1/admin/plans
Body: {
  name: "Premium",
  description: "Treino + Dieta + Chatbot IA",
  price: 150.00,
  duration_months: 1
}
Response: { id: UUID, name, price, duration_months, created_at, ... }

# GET /api/v1/admin/plans
# Listar planos do admin
GET /api/v1/admin/plans
Response: [
  { id: UUID, name, price, duration_months, is_active, ... }
]

# PUT /api/v1/admin/plans/{plan_id}
# Editar plano
PUT /api/v1/admin/plans/{plan_id}
Body: { name, price, duration_months, ... }
Response: { id, ...updated_plan }

# DELETE /api/v1/admin/plans/{plan_id}
# Deletar plano (soft delete)
DELETE /api/v1/admin/plans/{plan_id}
Response: { success: true }
```

---

### Admin: Visualizar Assinaturas

```python
# GET /api/v1/admin/subscriptions
# Listar todas as assinaturas do admin
GET /api/v1/admin/subscriptions?status=active&page=1
Response: [
  {
    id: UUID,
    student: { id, name, email, avatar_url },
    plan: { name, price, duration_months },
    status: "active",
    started_at: "2026-05-07T10:30:00Z",
    expires_at: "2026-06-07T23:59:59Z",
    days_until_expiry: 31,
    payment_method: "credit_card"
  }
]

# GET /api/v1/admin/subscriptions/{subscription_id}
# Detalhes de uma assinatura
GET /api/v1/admin/subscriptions/{subscription_id}
Response: {
  id: UUID,
  student: { id, name, email, phone },
  plan: { id, name, price, duration_months },
  status: "active",
  payment_method: "credit_card",
  started_at: TIMESTAMP,
  expires_at: TIMESTAMP,
  external_payment_id: "pay_xxx",
  created_at: TIMESTAMP
}
```

---

### Aluno: Contratar Plano

```python
# POST /api/v1/subscriptions/checkout
# Criar checkout para contratação
POST /api/v1/subscriptions/checkout
Body: {
  plan_id: UUID,
  payment_method: "credit_card" | "pix"
}
Response: {
  subscription_id: UUID,
  checkout_url: "https://asaas.com/checkout/xxx",
  external_payment_id: "pay_xxx",
  status: "pending"
}

# Aluno é redirecionado para o checkout
# Retorna ao app quando confirmar pagamento
```

---

### Aluno: Ver Assinatura Ativa

```python
# GET /api/v1/subscriptions/current
# Assinatura ativa do aluno
GET /api/v1/subscriptions/current
Response: {
  id: UUID,
  plan: { id, name, price, duration_months },
  status: "active",
  started_at: "2026-05-07T10:30:00Z",
  expires_at: "2026-06-07T23:59:59Z",
  days_until_expiry: 31,
  payment_method: "credit_card",
  next_billing_date: "2026-06-07T23:59:59Z"
}
```

---

### Webhook: Confirmação de Pagamento

```python
# POST /api/v1/webhooks/asaas
# Recebe callbacks de pagamento confirmado do gateway
POST /api/v1/webhooks/asaas
Headers: {
  "X-Signature": "hmac-sha256-signature"
}
Body: {
  event: "PAYMENT_CONFIRMED",
  id: "pay_xxx",
  externalReference: "sub_yyy",
  status: "CONFIRMED",
  value: 150.00
}

Backend:
1. Valida X-Signature com secret do Asaas
2. Busca subscription por external_payment_id
3. Muda status para ACTIVE
4. Calcula started_at = CURRENT_TIMESTAMP
5. Calcula expires_at = started_at + duration_months
6. Envia email de confirmação
7. Retorna 200 OK ao gateway (evita replay)
```

---

## 🔐 Segurança

### Autenticação & Autorização

```
✅ Apenas Admin pode criar/editar planos
✅ Apenas Personal pode marcar atendimentos
✅ Aluno pode ver apenas sua própria assinatura
✅ Webhook validado por assinatura (HMAC-SHA256)
✅ external_payment_id único e verificado antes de ativar
```

### Proteção contra Fraude

```
✅ Renovação automática verificada a cada ciclo
✅ Cancelamento manual requer confirmação do Admin
✅ Entradas duplicadas de webhook evitadas com idempotência
✅ Todas as transações logadas em audit trail
```

---

## 📊 Relatórios (Admin Dashboard)

### 1. Receita Mensal

```
Período: Maio 2026
Total de Assinaturas Ativas: 45
Receita MRR (Monthly Recurring Revenue): R$ 4.455,00
Churn Rate: 2.2%
LTV (Lifetime Value) médio: R$ 597,75
```

### 2. Evolução de Alunos

```
Gráfico:
- Novos: +12 (semana passada)
- Ativos: 45
- Inativos: 8
- Cancelados: 3
```

### 3. Distribuição por Plano

```
Pro (3 aval): 25 alunos → 60%
Basic (1 aval): 15 alunos → 35%
Premium (ilimitado): 5 alunos → 5%
```

---

## 🚀 Implementação (Fases)

### Fase 1: MVP V1 (1 semana)

**Backend (FastAPI):**
- [ ] Criar tabelas (plans, subscriptions) com SQLAlchemy
- [ ] Endpoints CRUD de plans (Admin)
- [ ] Endpoint de checkout (redireciona para Asaas)
- [ ] Webhook de confirmação (POST /webhooks/asaas)
- [ ] Máquina de estados (PENDING → ACTIVE → EXPIRED/CANCELED)
- [ ] Validação com Pydantic (CreatePlanDTO, SubscriptionDTO)
- [ ] Testes de integração (≥70% cobertura)

**Frontend (Flutter):**
- [ ] Tela "Planos Disponíveis" (list view com cards)
- [ ] Botão "Contratar" → Redireciona para Asaas
- [ ] Tela "Minha Assinatura" (status, validade)
- [ ] Mostrar informação de plano no perfil do aluno

**Segurança:**
- [ ] Validação de webhook por HMAC-SHA256
- [ ] Idempotência (evitar duplicação de webhook)
- [ ] Rate limiting nos endpoints

### Fase 2: Melhorias (Futuro - Após MVP validado)

- [ ] Dashboard Admin com relatórios (MRR, churn, LTV)
- [ ] Cancelamento manual de assinatura
- [ ] Notificações de vencimento (email/WhatsApp)
- [ ] Renovação com desconto (cupons)

### Fase 3: Avançado (Roadmap Futuro)

- [ ] Rastreamento de entregáveis (quando estabilizar MVP)
- [ ] Split de pagamentos (Marketplace)
- [ ] Relatórios avançados (PDF export)
- [ ] Integração com NF-e (emissão de nota fiscal)

---

## 📋 Critérios de Aceitação (MVP V1)

| Cenário | Resultado Esperado |
|---------|-------------------|
| Admin cria plano "Premium" | Plano criado com UUID único, preço e duração validados |
| Admin edita preço do plano | Alteração refletida no BD e listagem |
| Aluno visualiza planos | Lista todos os planos ativos com filtro por admin |
| Aluno clica "Contratar" | Redireciona para checkout do Asaas, subscription criada com status PENDING |
| Webhook de pagamento confirmado | Status muda para ACTIVE, started_at e expires_at calculados, email enviado |
| Webhook duplicado chega | Validação evita duplicate (idempotência) |
| Aluno acessa app com status ACTIVE | Treino, Dieta, IA, Logbook liberados |
| Aluno sem assinatura tenta acessar | Bloqueado com mensagem "Contratar plano" |
| Assinatura expira (cron job) | Status muda para EXPIRED, acesso bloqueado |
| Personal vê perfil do aluno | Exibe: "Plano: Premium R$ 150/mês até 07/06/2026" |
| Personal Autônomo cria planos | Consegue ser Admin e criar/editar planos |

---

## 🔧 Stack Técnico (MVP V1)

### Backend (FastAPI - Python)

```
Framework: FastAPI (async/await)
ORM: SQLAlchemy 2.0 (async)
Validação: Pydantic v2
Banco: PostgreSQL + pgvector (já em uso)
Gateway: Asaas SDK (Python)
Task Scheduler: APScheduler (cron jobs)
HTTP Client: httpx (async)
Auth: JWT (já em uso)
Logging: Python logging + estruturado
Testing: pytest + pytest-asyncio
```

**Por quê FastAPI?**
- ✅ Async nativo (melhor para webhooks)
- ✅ Tipagem com Pydantic (segurança)
- ✅ Performance excelente
- ✅ Documentação automática (Swagger)
- ✅ Já em uso no projeto

---

### Frontend (Flutter)

```
Framework: Flutter (já em uso)
State Management: Provider (já em uso)
HTTP: dio ou http package
UI: Material Design 3
Navigation: GoRouter
Observações: Reutilizar admin_provider e admin_service
```

---

### Banco de Dados (PostgreSQL)

```
Tabelas necessárias:
- plans (já definida)
- subscriptions (já definida)
- Sem deliverables, sem attendance_records (MVP V1)

Índices otimizados para queries de acesso
```

---

### Integração com Gateway (Asaas)

```
Endpoint Checkout: POST /customer/subscription
Webhook Endpoint: POST /api/v1/webhooks/asaas
Validação: HMAC-SHA256 (X-Signature header)
Status Events: PAYMENT_CONFIRMED, PAYMENT_FAILED
Documentação: https://docs.asaas.com/

Alternativa: Mercado Pago (se Asaas não funcionar)
```

---

## 🔗 Dependências

- **Gateway de Pagamento:** Asaas (recomendado para Brasil)
- **Email:** SendGrid ou SMTP simples (notificações)
- **Banco de Dados:** PostgreSQL ≥13 com UUID support
- **Task Scheduler:** APScheduler (expirações automáticas)
- **HTTP Client:** httpx (async requests)

---

## 📝 Notas Importantes (MVP V1)

1. **Sem pró-rata:** Reembolsos são negociados manualmente (fora do app)
2. **Acesso universal:** Nenhuma tela fica bloqueada por plano (binário: ACTIVE ou não)
3. **Sem entregáveis:** Personal gerencia avaliações no WhatsApp/Google Calendar
4. **Multi-tenant:** Suporta Academias e Personals Autônomos
5. **Imediato:** Pagou = começou usando agora (sem carência)
6. **Idempotência:** Webhooks duplicados não criam duplicatas
7. **Renovação automática:** Cartão cobra automaticamente; Pix manda link 3 dias antes

---

## 🎯 Checklist Antes de Começar Desenvolvimento

**Preparação:**
- [ ] Conta Asaas criada e testada (sandbox)
- [ ] Documentação Asaas lida (webhooks e APIs)
- [ ] Repositório atualizado em `feat/payments-subscriptions`
- [ ] Equipe alinhada no escopo simplificado (sem entregáveis)

**Desenvolvimento Backend (FastAPI):**
- [ ] Models SQLAlchemy (plans, subscriptions)
- [ ] DTOs Pydantic (validation)
- [ ] Repository layer (operações DB)
- [ ] Service layer (lógica de negócio)
- [ ] Routes e controllers
- [ ] Webhook handler (Asaas)
- [ ] Tests com pytest

**Desenvolvimento Frontend (Flutter):**
- [ ] Tela de planos (listagem)
- [ ] Integração com checkout Asaas
- [ ] Tela de minha assinatura
- [ ] Exibição de plano no perfil
- [ ] Tests de widgets

**Deploy:**
- [ ] Variáveis de ambiente (ASAAS_API_KEY, WEBHOOK_SECRET)
- [ ] Testes em staging com Asaas
- [ ] Webhook configurado em produção

---

## 📞 Questões em Aberto (Para Futuro)

1. Integração com WhatsApp para lembretes? (Fase 2)
2. Cupons de desconto? (Fase 2)
3. Upgrade/downgrade mid-ciclo? (Fase 3)
4. Rastreamento de entregáveis? (Fase 3 - após MVP estável)

---

## ✅ Status Final

**Este PRD define o MVP V1 de Pagamentos e Assinaturas:**
- Simplicidade extrema (apenas 2 tabelas)
- Foco em acesso/acesso bloqueado
- Zero complexidade de entregáveis
- Pronto para ser estendido nas fases futuras

**Próximas Ações:**
1. ✅ PR_D criado e validado com a equipe
2. 🔜 Criar migrations SQLAlchemy (plans, subscriptions)
3. 🔜 Implementar endpoints CRUD (FastAPI)
4. 🔜 Integrar webhook Asaas
5. 🔜 Testes end-to-end
6. 🔜 Frontend (Flutter) conecta ao backend
