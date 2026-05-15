# 📋 Plano de Implementação: Módulo de Pagamentos e Assinaturas

**Status:** 🟢 Pronto para Desenvolvimento  
**Duração Estimada:** 1 semana (5 dias úteis)  
**Equipe:** Backend (FastAPI) + Frontend (Flutter)  
**Baseado em:** PRD_PAGAMENTOS_ASSINATURAS.md (v1.1)

---

## 🎯 Visão Geral

Este plano detalha **como** implementar o módulo de Pagamentos e Assinaturas (MVP V1) com foco em simplicidade e acesso ao software como gatekeeper.

**Resultado esperado:** Aluno contrata plano → Paga → Acesso liberado ✅

---

## 📅 Timeline (Semana 1)

| Dia | Tarefa | Responsável | Status |
|-----|--------|-------------|--------|
| **D1** | Setup Backend + Schema DB | Backend | ⬜ |
| **D1** | Migrations SQLAlchemy | Backend | ⬜ |
| **D2** | DTOs (Pydantic) + Models | Backend | ⬜ |
| **D2** | Repository layer (plans, subscriptions) | Backend | ⬜ |
| **D3** | Service layer (lógica) | Backend | ⬜ |
| **D3** | Endpoints CRUD (planos) | Backend | ⬜ |
| **D4** | Webhook handler (Asaas) | Backend | ⬜ |
| **D4** | Testes unitários + integração | Backend | ⬜ |
| **D5** | Telas Frontend (planos, checkout, minha assinatura) | Frontend | ⬜ |
| **D5** | Integração Frontend ↔ Backend | Frontend | ⬜ |

---

## 🔵 FASE 1: Backend (Dias 1-4)

### ⚙️ D1: Setup Backend + Schema

**Objetivo:** Preparar ambiente e criar schema do banco

#### 1.1 Verificar dependências no `requirements.txt`

```bash
# Acessar backend
cd backend

# Verificar se estas dependências existem:
# - fastapi
# - sqlalchemy>=2.0
# - pydantic>=2.0
# - httpx (para chamadas Asaas)
# - apscheduler (para cron jobs)
# - python-jose (JWT - já deve estar)

# Se faltar algo, adicionar:
pip install asaas-sdk  # SDK Python do Asaas (se existir)
# Ou usar httpx diretamente
```

**Checklist:**
- [ ] `pip install -r requirements.txt` funciona sem erros
- [ ] `docker compose up` levanta a API
- [ ] PostgreSQL está acessível

---

#### 1.2 Criar arquivo de migração SQLAlchemy

**Arquivo:** `backend/app/migrations/004_create_payments_tables.py`

```python
"""
Migração para criar tabelas de Pagamentos e Assinaturas (MVP V1)
"""
from sqlalchemy import Column, String, Numeric, Integer, DateTime, Boolean, ForeignKey, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid

from app.models.base import Base

class Plan(Base):
    """Planos disponíveis para contratação"""
    __tablename__ = "plans"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    admin_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Identificação
    name = Column(String(100), nullable=False)
    description = Column(String(500))
    
    # Financeiro
    price = Column(Numeric(10, 2), nullable=False)
    currency = Column(String(3), default="BRL")
    
    # Duração
    duration_months = Column(Integer, nullable=False)  # 1, 3, 6, 12
    
    # Metadata
    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    updated_at = Column(TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow)
    deleted_at = Column(TIMESTAMP, nullable=True)
    
    __table_args__ = (
        # Constraints
    )


class Subscription(Base):
    """Assinaturas dos alunos"""
    __tablename__ = "subscriptions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    plan_id = Column(UUID(as_uuid=True), ForeignKey("plans.id"), nullable=False)
    admin_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    # Status
    status = Column(String(20), default="pending")  # pending, active, expired, canceled_pending, canceled
    
    # Pagamento
    payment_method = Column(String(20))  # pix, credit_card
    external_payment_id = Column(String(100), unique=True)  # ID do Asaas
    
    # Datas
    started_at = Column(TIMESTAMP, nullable=True)
    expires_at = Column(TIMESTAMP, nullable=True)
    canceled_at = Column(TIMESTAMP, nullable=True)
    
    # Metadata
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    updated_at = Column(TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (
        # Index para queries rápidas
    )
```

**Checklist:**
- [ ] Arquivo criado em `backend/app/migrations/004_create_payments_tables.py`
- [ ] Imports corretos (SQLAlchemy, datetime, uuid)
- [ ] Duas classes: `Plan` e `Subscription`

---

#### 1.3 Executar migrations

```bash
# Dentro do container ou localmente
cd backend

# Se usar Alembic (já em uso no projeto):
alembic upgrade head

# Ou manualmente:
python -c "from app.models import Base; from app.config.database import engine; Base.metadata.create_all(engine)"

# Verificar no BD:
psql -U omni_user -d omniconnect_db -c "\dt"
# Deve listar: plans, subscriptions
```

**Checklist:**
- [ ] Tabelas `plans` e `subscriptions` criadas no PostgreSQL
- [ ] Índices criados
- [ ] Sem erros de constraint

---

### 📦 D2: DTOs + Models

**Objetivo:** Criar validação (Pydantic) e modelos de banco

#### 2.1 Criar DTOs (Pydantic) para Pagamentos

**Arquivo:** `backend/app/dtos/payment_dtos.py`

```python
"""
Data Transfer Objects para Pagamentos e Assinaturas
"""
from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from decimal import Decimal

# ============= PLANS =============

class CreatePlanDTO(BaseModel):
    """DTO para criar um plano"""
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    price: Decimal = Field(..., gt=0, decimal_places=2)
    duration_months: int = Field(..., ge=1)
    
    @validator('duration_months')
    def validate_duration(cls, v):
        if v not in [1, 3, 6, 12]:
            raise ValueError('Duração deve ser 1, 3, 6 ou 12 meses')
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "name": "Premium",
                "description": "Treino + Dieta + IA",
                "price": 150.00,
                "duration_months": 1
            }
        }


class UpdatePlanDTO(BaseModel):
    """DTO para atualizar um plano"""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    price: Optional[Decimal] = Field(None, gt=0)
    duration_months: Optional[int] = Field(None, ge=1)
    is_active: Optional[bool] = None
    
    class Config:
        json_schema_extra = {
            "example": {
                "price": 199.90
            }
        }


class PlanResponseDTO(BaseModel):
    """DTO de resposta para um plano"""
    id: UUID
    admin_id: UUID
    name: str
    description: Optional[str]
    price: Decimal
    currency: str
    duration_months: int
    is_active: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


# ============= SUBSCRIPTIONS =============

class CreateSubscriptionDTO(BaseModel):
    """DTO para criar checkout de assinatura"""
    plan_id: UUID
    payment_method: str = Field(..., regex="^(credit_card|pix)$")
    
    class Config:
        json_schema_extra = {
            "example": {
                "plan_id": "550e8400-e29b-41d4-a716-446655440000",
                "payment_method": "credit_card"
            }
        }


class SubscriptionResponseDTO(BaseModel):
    """DTO de resposta para assinatura"""
    id: UUID
    student_id: UUID
    plan_id: UUID
    status: str
    payment_method: Optional[str]
    started_at: Optional[datetime]
    expires_at: Optional[datetime]
    days_until_expiry: Optional[int] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


class SubscriptionDetailDTO(SubscriptionResponseDTO):
    """DTO detalhado com informações do plano"""
    plan: Optional[PlanResponseDTO] = None


# ============= WEBHOOK =============

class AsaasWebhookDTO(BaseModel):
    """DTO para webhook do Asaas"""
    event: str  # PAYMENT_CONFIRMED, PAYMENT_FAILED, etc
    id: str  # ID do pagamento no Asaas
    externalReference: Optional[str]  # External reference (subscription_id)
    status: str  # CONFIRMED, FAILED, etc
    value: Optional[Decimal]  # Valor pago
    
    class Config:
        json_schema_extra = {
            "example": {
                "event": "PAYMENT_CONFIRMED",
                "id": "pay_123456",
                "externalReference": "sub_550e8400",
                "status": "CONFIRMED",
                "value": 150.00
            }
        }
```

**Checklist:**
- [ ] Arquivo `backend/app/dtos/payment_dtos.py` criado
- [ ] 6 DTOs implementados com validação Pydantic
- [ ] Validators para duration_months
- [ ] Regex para payment_method

---

#### 2.2 Atualizar Models SQLAlchemy

**Arquivo:** `backend/app/models/payment.py` (novo)

```python
"""
Modelos SQLAlchemy para Pagamentos e Assinaturas
"""
from sqlalchemy import Column, String, Numeric, Integer, DateTime, Boolean, ForeignKey, TIMESTAMP, desc
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.models.base import Base


class Plan(Base):
    """Plano de assinatura"""
    __tablename__ = "plans"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    admin_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    name = Column(String(100), nullable=False)
    description = Column(String(500))
    
    price = Column(Numeric(10, 2), nullable=False)
    currency = Column(String(3), default="BRL")
    duration_months = Column(Integer, nullable=False)
    
    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    updated_at = Column(TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow)
    deleted_at = Column(TIMESTAMP, nullable=True)
    
    # Relationships
    subscriptions = relationship("Subscription", back_populates="plan", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Plan id={self.id} name={self.name} price={self.price}>"


class Subscription(Base):
    """Assinatura de um aluno"""
    __tablename__ = "subscriptions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    plan_id = Column(UUID(as_uuid=True), ForeignKey("plans.id"), nullable=False)
    admin_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    status = Column(String(20), default="pending")  # pending, active, expired, canceled_pending, canceled
    payment_method = Column(String(20))  # pix, credit_card
    external_payment_id = Column(String(100), unique=True)
    
    started_at = Column(TIMESTAMP, nullable=True)
    expires_at = Column(TIMESTAMP, nullable=True)
    canceled_at = Column(TIMESTAMP, nullable=True)
    
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    updated_at = Column(TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    plan = relationship("Plan", back_populates="subscriptions")
    
    def __repr__(self):
        return f"<Subscription id={self.id} student_id={self.student_id} status={self.status}>"
    
    def is_active_now(self) -> bool:
        """Verifica se a assinatura está ativa agora"""
        if self.status != "active":
            return False
        if self.expires_at and self.expires_at < datetime.utcnow():
            return False
        return True
```

**Checklist:**
- [ ] Arquivo `backend/app/models/payment.py` criado
- [ ] Classes `Plan` e `Subscription` com relationships
- [ ] Método `is_active_now()` em Subscription
- [ ] Imports corretos

---

### 💾 D2: Repository Layer

**Arquivo:** `backend/app/repositories/payment_repository.py` (novo)

```python
"""
Repository layer para operações de Pagamentos
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, and_, desc
from typing import Optional, List
from uuid import UUID
from datetime import datetime

from app.models.payment import Plan, Subscription
from app.dtos.payment_dtos import CreatePlanDTO, UpdatePlanDTO


class PlanRepository:
    """Operações de banco para Plans"""
    
    @staticmethod
    async def create(session: AsyncSession, admin_id: UUID, dto: CreatePlanDTO) -> Plan:
        """Criar novo plano"""
        plan = Plan(
            admin_id=admin_id,
            name=dto.name,
            description=dto.description,
            price=dto.price,
            duration_months=dto.duration_months
        )
        session.add(plan)
        await session.flush()
        return plan
    
    @staticmethod
    async def find_by_id(session: AsyncSession, plan_id: UUID) -> Optional[Plan]:
        """Buscar plano por ID"""
        result = await session.execute(select(Plan).where(Plan.id == plan_id))
        return result.scalars().first()
    
    @staticmethod
    async def find_by_admin(session: AsyncSession, admin_id: UUID, only_active: bool = True) -> List[Plan]:
        """Listar planos de um admin"""
        query = select(Plan).where(Plan.admin_id == admin_id)
        if only_active:
            query = query.where(Plan.is_active == True)
        query = query.order_by(desc(Plan.created_at))
        result = await session.execute(query)
        return result.scalars().all()
    
    @staticmethod
    async def update(session: AsyncSession, plan_id: UUID, dto: UpdatePlanDTO) -> Optional[Plan]:
        """Atualizar plano"""
        plan = await PlanRepository.find_by_id(session, plan_id)
        if not plan:
            return None
        
        update_data = dto.dict(exclude_unset=True)
        for key, value in update_data.items():
            setattr(plan, key, value)
        
        await session.flush()
        return plan
    
    @staticmethod
    async def soft_delete(session: AsyncSession, plan_id: UUID) -> bool:
        """Soft delete (marca como deletado)"""
        plan = await PlanRepository.find_by_id(session, plan_id)
        if not plan:
            return False
        
        plan.deleted_at = datetime.utcnow()
        await session.flush()
        return True


class SubscriptionRepository:
    """Operações de banco para Subscriptions"""
    
    @staticmethod
    async def create(session: AsyncSession, student_id: UUID, plan_id: UUID, 
                    admin_id: UUID, payment_method: str) -> Subscription:
        """Criar nova assinatura (status PENDING)"""
        subscription = Subscription(
            student_id=student_id,
            plan_id=plan_id,
            admin_id=admin_id,
            payment_method=payment_method,
            status="pending"
        )
        session.add(subscription)
        await session.flush()
        return subscription
    
    @staticmethod
    async def find_by_id(session: AsyncSession, subscription_id: UUID) -> Optional[Subscription]:
        """Buscar assinatura por ID"""
        result = await session.execute(
            select(Subscription).where(Subscription.id == subscription_id)
        )
        return result.scalars().first()
    
    @staticmethod
    async def find_by_external_id(session: AsyncSession, external_payment_id: str) -> Optional[Subscription]:
        """Buscar assinatura por ID externo (Asaas)"""
        result = await session.execute(
            select(Subscription).where(Subscription.external_payment_id == external_payment_id)
        )
        return result.scalars().first()
    
    @staticmethod
    async def find_student_active(session: AsyncSession, student_id: UUID) -> Optional[Subscription]:
        """Buscar assinatura ativa do aluno"""
        result = await session.execute(
            select(Subscription)
            .where(
                and_(
                    Subscription.student_id == student_id,
                    Subscription.status == "active"
                )
            )
        )
        return result.scalars().first()
    
    @staticmethod
    async def find_by_admin(session: AsyncSession, admin_id: UUID, status: Optional[str] = None) -> List[Subscription]:
        """Listar assinaturas de um admin"""
        query = select(Subscription).where(Subscription.admin_id == admin_id)
        if status:
            query = query.where(Subscription.status == status)
        query = query.order_by(desc(Subscription.created_at))
        result = await session.execute(query)
        return result.scalars().all()
    
    @staticmethod
    async def activate(session: AsyncSession, subscription_id: UUID, payment_method: str, 
                      external_payment_id: str) -> bool:
        """Ativar assinatura (webhook confirmado)"""
        subscription = await SubscriptionRepository.find_by_id(session, subscription_id)
        if not subscription:
            return False
        
        # Calcular datas
        subscription.status = "active"
        subscription.started_at = datetime.utcnow()
        # expires_at = started_at + duration_months (calcular com relativedelta)
        subscription.external_payment_id = external_payment_id
        
        await session.flush()
        return True
    
    @staticmethod
    async def expire_outdated(session: AsyncSession) -> int:
        """Cron job: marcar assinaturas expiradas como EXPIRED"""
        now = datetime.utcnow()
        
        stmt = (
            update(Subscription)
            .where(
                and_(
                    Subscription.status == "active",
                    Subscription.expires_at < now
                )
            )
            .values(status="expired")
        )
        
        result = await session.execute(stmt)
        await session.flush()
        return result.rowcount
```

**Checklist:**
- [ ] Arquivo `backend/app/repositories/payment_repository.py` criado
- [ ] `PlanRepository` com CRUD
- [ ] `SubscriptionRepository` com lifecycle
- [ ] Método `expire_outdated()` para cron

---

### 🧠 D3: Service Layer

**Arquivo:** `backend/app/services/payment_service.py` (novo)

Será criado com lógica de negócio:
- Criar checkout
- Processar webhook
- Validar acesso
- Calcular datas de expiração

**Checklist:**
- [ ] Arquivo criado
- [ ] Métodos async
- [ ] Tratamento de exceções
- [ ] Logging

---

### 🌐 D3: Routes/Endpoints (FastAPI)

**Arquivo:** `backend/app/routes/payment.py` (novo)

Endpoints:
- `POST /api/v1/admin/plans` - Criar plano
- `GET /api/v1/admin/plans` - Listar planos
- `PUT /api/v1/admin/plans/{id}` - Atualizar plano
- `GET /api/v1/admin/subscriptions` - Listar assinaturas
- `POST /api/v1/subscriptions/checkout` - Criar checkout
- `GET /api/v1/subscriptions/current` - Minha assinatura
- `POST /api/v1/webhooks/asaas` - Webhook de pagamento

**Checklist:**
- [ ] Arquivo criado
- [ ] Todos os 7 endpoints implementados
- [ ] Autenticação em cada rota
- [ ] Responses tipados (OpenAPI docs)

---

### 🪝 D4: Webhook Handler

**Arquivo:** `backend/app/routes/payment.py` (endpoint específico)

```python
@router.post("/webhooks/asaas")
async def handle_asaas_webhook(
    request: Request,
    session: AsyncSession = Depends(get_session)
):
    """
    Recebe webhooks de pagamento confirmado do Asaas
    
    Validação:
    1. Verificar X-Signature header (HMAC-SHA256)
    2. Buscar subscription por external_payment_id
    3. Ativar subscription (status=ACTIVE, datas calculadas)
    4. Enviar email de confirmação
    5. Retornar 200 OK (evita retry do Asaas)
    """
```

**Checklist:**
- [ ] Validação de assinatura HMAC-SHA256
- [ ] Idempotência (evitar duplicação)
- [ ] Logging de todos os eventos
- [ ] Tratamento de erros (retorna 200 mesmo em erro, para não fazer retry infinito)

---

### 🧪 D4: Testes

**Arquivo:** `backend/tests/test_payments.py` (novo)

Testes para:
- ✅ Criar plano
- ✅ Listar planos
- ✅ Criar checkout (subscription PENDING)
- ✅ Webhook confirmado (subscription ACTIVE)
- ✅ Webhook duplicado (idempotência)
- ✅ Validação de datas
- ✅ Acesso bloqueado sem assinatura

**Alvo:** ≥80% cobertura

**Checklist:**
- [ ] Arquivo criado com pelo menos 10 testes
- [ ] Fixtures para plans e subscriptions
- [ ] Mocks do Asaas
- [ ] `pytest --cov=app.services.payment_service` ≥80%

---

## 🟠 FASE 2: Frontend (D5)

### 📱 D5: Telas Flutter

#### 5.1 Tela de Planos

**Arquivo:** `frontend/lib/screens/student/plans_screen.dart`

```dart
class PlansScreen extends StatefulWidget {
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late Future<List<Plan>> _plansF uture;
  
  @override
  void initState() {
    super.initState();
    _plansFuture = _adminService.getAvailablePlans();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Planos")),
      body: FutureBuilder(
        future: _plansFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ListView(
              children: snapshot.data!.map((plan) {
                return PlanCard(
                  plan: plan,
                  onContratarPressed: () => _handleCheckout(plan),
                );
              }).toList(),
            );
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
```

**Checklist:**
- [ ] Tela lista planos do admin atual
- [ ] Card para cada plano (nome, preço, duração)
- [ ] Botão "Contratar Agora"
- [ ] Loading e error states

---

#### 5.2 Checkout com Asaas

```dart
Future<void> _handleCheckout(Plan plan) async {
  // 1. Chamar backend: POST /api/v1/subscriptions/checkout
  // 2. Receber checkout_url
  // 3. Abrir em WebView ou navegador
  // 4. Usuário paga
  // 5. Webhook chega no backend
  // 6. Retornar ao app
  // 7. Atualizar status
}
```

**Checklist:**
- [ ] Integração com WebView ou url_launcher
- [ ] Redireciona para checkout Asaas
- [ ] Captura resultado (sucesso/cancelamento)

---

#### 5.3 Tela "Minha Assinatura"

**Arquivo:** `frontend/lib/screens/student/my_subscription_screen.dart`

```dart
class MySubscriptionScreen extends StatefulWidget {
  @override
  State<MySubscriptionScreen> createState() => _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends State<MySubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }
  
  Future<void> _loadSubscription() async {
    // GET /api/v1/subscriptions/current
    // Exibir: nome do plano, validade, próxima renovação
  }
}
```

**Checklist:**
- [ ] Exibe plano contratado
- [ ] Data de contratação
- [ ] Data de expiração
- [ ] Status (ACTIVE, PENDING, EXPIRED)
- [ ] Botão "Renovar" se expirado

---

#### 5.4 Integração Frontend ↔ Backend

**Arquivo:** `frontend/lib/services/payment_service.dart`

```dart
class PaymentService {
  Future<SubscriptionResponse> createCheckout(
    String planId, 
    String paymentMethod
  ) async {
    // POST /api/v1/subscriptions/checkout
  }
  
  Future<SubscriptionResponse> getCurrentSubscription() async {
    // GET /api/v1/subscriptions/current
  }
  
  Future<List<Plan>> getAvailablePlans() async {
    // GET /api/v1/admin/plans (do admin atual)
  }
}
```

**Checklist:**
- [ ] Service criado com 3 métodos
- [ ] Tratamento de erros HTTP
- [ ] Retry logic
- [ ] Logging

---

#### 5.5 Bloquear acesso sem assinatura

**Arquivo:** `frontend/lib/screens/student/student_shell.dart`

```dart
@override
Widget build(BuildContext context) {
  return FutureBuilder(
    future: _checkSubscription(),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data!.isActive) {
        // Mostrar app normal (treino, dieta, IA, logbook)
        return StudentApp();
      } else {
        // Mostrar tela de planos ("Contratar plano para acessar")
        return PlansScreen();
      }
    },
  );
}
```

**Checklist:**
- [ ] Gate de acesso no shell
- [ ] Verifica subscription status
- [ ] Bloqueia se não ACTIVE
- [ ] Redireciona para planos

---

## 📊 Checklist Completo

### Backend
- [ ] D1: Schema + Migrations
- [ ] D2: DTOs + Models
- [ ] D2: Repository Layer
- [ ] D3: Service Layer
- [ ] D3: Routes/Endpoints
- [ ] D4: Webhook Handler
- [ ] D4: Testes (≥80% cobertura)
- [ ] Documentação (Swagger/OpenAPI)

### Frontend
- [ ] D5: Tela Planos
- [ ] D5: Checkout Integration
- [ ] D5: Tela Minha Assinatura
- [ ] D5: Payment Service
- [ ] D5: Access Gate
- [ ] D5: Testes de Widget

### DevOps
- [ ] Variáveis de ambiente (.env)
  - `ASAAS_API_KEY`
  - `ASAAS_WEBHOOK_SECRET`
  - `ASAAS_BASE_URL` (sandbox ou prod)
- [ ] Docker compose atualizado (se necessário)
- [ ] Migrations rodadas em staging

### Documentação
- [ ] README atualizado
- [ ] API docs (Swagger)
- [ ] Exemplos de uso
- [ ] Troubleshooting

---

## 🚨 Riscos & Contingências

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|--------|-----------|
| Asaas SDK não existe | Média | Alto | Usar httpx + requests diretos |
| Webhook não chega | Baixa | Alto | Implementar polling como fallback |
| Timezone issues | Média | Médio | Usar UTC everywhere + testing |
| Rate limiting Asaas | Baixa | Médio | Cache responses, respeitar rate limit |

---

## ✅ Critérios de Conclusão

Fase 1 concluída quando:
- ✅ Todos os 7 endpoints funcionando (testados com Postman/Insomnia)
- ✅ Webhook testado com Asaas sandbox
- ✅ Testes com ≥80% cobertura
- ✅ Sem erros no `docker logs omniconnect-api`

Fase 2 concluída quando:
- ✅ Telas renderizam sem crashes
- ✅ Checkout redireciona para Asaas
- ✅ Acesso bloqueado sem subscription
- ✅ E2E test: criar conta → contratar plano → acessar app

---

## 🎯 Próximos Passos Imediatos

1. **Setup do dia 1:**
   - [ ] Criar branch `feat/payments-subscriptions` (já feita)
   - [ ] Adicionar dependências no `requirements.txt`
   - [ ] Criar arquivo de migration

2. **Kick-off da equipe:**
   - [ ] Revisar este plano com o time
   - [ ] Dividir tarefas por pessoa
   - [ ] Setup de ambiente local (Asaas sandbox)

3. **Daily standup:**
   - Cada dia ao final: repassar checklist, blockers, adaptações

---

**Plano criado:** 2026-05-07  
**Versão:** 1.0  
**Status:** 🟢 Pronto para execução

