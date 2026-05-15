# PRD: Metas Alcançadas - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-04-21  
**Status:** 📋 Em Especificação  
**Responsável:** William

---

## 📋 1. Visão Geral

### Objetivo
Criar um sistema de gerenciamento de metas que permita:
- ✅ Personal e Aluno definirem metas mensuráveis (ex: aumentar supino 10kg em 60 dias)
- ✅ Sistema calcular automaticamente progresso percentual
- ✅ Notificação comemorativa ao atingir meta
- ✅ Histórico de metas concluídas e em andamento
- ✅ Suporte a múltiplas categorias (força, resistência, composição, frequência)

### Por Quê?
Metas motivam alunos e estruturam treino:
- **Engagement:** Aluno vê objetivo claro
- **Rastreamento:** Personal acompanha progresso
- **Validação:** Prova de resultado do treino
- **Progresso:** Integra com logbook (RF-17)

### Escopo
✅ **Incluído:**
- Criar meta com data-alvo
- Rastrear progresso (% completo)
- Notificação ao atingir/ultrapassar
- Histórico de metas

❌ **NÃO incluído:**
- Sugestões automáticas de meta (futuro)
- Análise preditiva (futuro)

---

## 📊 2. Especificação Técnica

### 2.1 Modelo de Dados

#### Tabela: Goal (Meta)
```python
class Goal(Base):
    """Meta do aluno"""
    
    __tablename__ = "goals"
    
    id: UUID
    user_id: UUID                 # Aluno (FK Users)
    created_by_id: UUID           # Quem criou (Personal/Gestor)
    
    # Descrição
    title: str                    # "Aumentar supino em 10kg"
    description: str              # Detalhes da meta
    category: str                 # "strength", "endurance", "composition", "frequency"
    
    # Valores
    target_value: float           # Valor alvo (ex: 100kg)
    current_value: float          # Valor atual quando criada
    initial_value: float          # Primeiro valor registrado
    unit: str                     # "kg", "%", "days/week", "cm"
    
    # Datas
    start_date: datetime          # Quando começou
    target_date: datetime         # Data que quer atingir
    completed_at: datetime        # Quando completou (NULL se ainda em progresso)
    
    # Status
    status: str                   # "active", "completed", "failed", "paused"
    progress_percentage: float    # 0-100% (calculado)
    
    # Auditoria
    created_at: datetime
    updated_at: datetime
    
    # Relações
    progress_entries: List[GoalProgressEntry]
```

#### Tabela: GoalProgressEntry (Histórico de Progresso)
```python
class GoalProgressEntry(Base):
    """Cada vez que meta é atualizada"""
    
    __tablename__ = "goal_progress_entries"
    
    id: UUID
    goal_id: UUID                 # Meta (FK Goals)
    current_value: float          # Valor atual
    session_id: UUID              # Sessão de logbook onde conseguiu (FK WorkoutSessions)
    recorded_at: datetime         # Quando registrou
    notes: str                    # Observações
    created_at: datetime
```

---

### 2.2 DTOs

#### CreateGoalDTO
```json
{
  "title": "Aumentar supino em 10kg",
  "description": "Do 80kg para 90kg",
  "category": "strength",
  "target_value": 90.0,
  "current_value": 80.0,
  "unit": "kg",
  "target_date": "2026-06-21"
}
```

**Validações:**
- ✅ `title`: 3-255 chars
- ✅ `target_value` > `current_value` (ou < se é reduzir)
- ✅ `target_date`: no futuro
- ✅ `category`: enum válido

#### GoalResponseDTO
```json
{
  "id": "550e8400...",
  "user_id": "550e8400...",
  "title": "Aumentar supino em 10kg",
  "category": "strength",
  "target_value": 90.0,
  "current_value": 80.0,
  "initial_value": 80.0,
  "unit": "kg",
  "start_date": "2026-04-21T00:00:00Z",
  "target_date": "2026-06-21T00:00:00Z",
  "status": "active",
  "progress_percentage": 0.0,
  "days_remaining": 61,
  "completed_at": null,
  "created_at": "2026-04-21T10:00:00Z"
}
```

---

## 🔌 3. Endpoints HTTP

### 3.1 POST /api/v1/goals (Criar Meta)

**Request:**
```http
POST /api/v1/goals HTTP/1.1
Authorization: Bearer {token}

{
  "title": "Aumentar supino em 10kg",
  "category": "strength",
  "target_value": 90.0,
  "current_value": 80.0,
  "unit": "kg",
  "target_date": "2026-06-21"
}
```

**Response 201:**
```json
{ "id": "550e8400...", "progress_percentage": 0.0 }
```

---

### 3.2 GET /api/v1/goals (Listar Metas)

**Request:**
```http
GET /api/v1/goals?user_id=550e8400...&status=active&page=1 HTTP/1.1
Authorization: Bearer {token}
```

**Response 200:**
```json
{
  "total": 5,
  "page": 1,
  "data": [
    {
      "id": "550e8400...",
      "title": "Aumentar supino em 10kg",
      "status": "active",
      "progress_percentage": 25.0,
      "days_remaining": 55
    }
  ]
}
```

---

### 3.3 GET /api/v1/goals/{id} (Detalhe Meta)

**Response 200:**
```json
{
  "id": "550e8400...",
  "title": "Aumentar supino em 10kg",
  "progress_percentage": 25.0,
  "current_value": 82.5,
  "target_value": 90.0,
  "progress_entries": [
    {
      "current_value": 80.0,
      "recorded_at": "2026-04-21T18:30:00Z",
      "notes": "Início"
    },
    {
      "current_value": 82.5,
      "recorded_at": "2026-04-25T18:30:00Z",
      "notes": "Progresso"
    }
  ]
}
```

---

### 3.4 PUT /api/v1/goals/{id} (Atualizar Meta)

**Request:**
```http
PUT /api/v1/goals/550e8400... HTTP/1.1
Authorization: Bearer {token}

{
  "current_value": 85.0,
  "notes": "Consegui 85kg com 4 séries"
}
```

**Response 200:**
```json
{
  "id": "550e8400...",
  "progress_percentage": 62.5,
  "current_value": 85.0,
  "status": "active"
}
```

⚠️ **Nota:** Se `current_value >= target_value`, meta muda para "completed"

---

### 3.5 DELETE /api/v1/goals/{id} (Deletar Meta)

**Response 204**

---

## 🔐 4. Requisitos de Segurança

- ✅ Aluno pode ver/editar SUAS metas
- ✅ Personal pode ver/editar metas dos alunos vinculados
- ✅ Admin pode ver todas as metas
- ✅ `current_value` só pode aumentar ou ser atualizado por aluno/personal

---

## 🧪 5. Testes (8+ testes)

**Teste 1:** Criar meta com sucesso  
**Teste 2:** Listar metas ativas  
**Teste 3:** Atualizar progresso e calcular %  
**Teste 4:** Completar meta automaticamente  
**Teste 5:** Não pode criar meta com data passada  
**Teste 6:** Controle de acesso  
**Teste 7:** Histórico de progresso  
**Teste 8:** Deletar meta  

---

## 🎯 Definição de Pronto

- ✅ 5 endpoints funcionando
- ✅ Cálculo automático de progresso
- ✅ Status "completed" ao atingir target
- ✅ Histórico rastreável
- ✅ 8+ testes
- ✅ Cobertura ≥80%

---

## 📁 Arquivos a Criar

```
backend/app/
├── models/goal.py
├── dtos/goal_dto.py
├── services/goal_service.py
├── repositories/goal_repository.py
├── controllers/goal_controller.py
├── routes/goal.py
tests/
├── test_goals.py
└── unit/test_goal_*.py
```

---

## ⚡ Tempo Estimado: 10 horas

- Models + DTOs: 2h
- Service + Repository: 2h
- Endpoints: 3h
- Testes: 3h

---

*PRD para OmniConnect Fitness - Data: 21 Abril 2026*
