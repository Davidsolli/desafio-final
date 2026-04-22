# PRD: Montagem de Ficha de Treino - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-04-19  
**Status:** 📋 Em Revisão  
**Responsável:** José Henrique.

---

## 📋 1. Visão Geral

### Objetivo
Criar um sistema completo de gerenciamento de fichas de treino que permita:
- ✅ Personal/Professor criar fichas com múltiplos exercícios
- ✅ Organizar exercícios por grupos musculares
- ✅ Registrar detalhes de cada exercício (séries, repetições, carga, etc)
- ✅ Demonstrar exercícios via imagem/GIF
- ✅ Atribuir fichas diferentes para dias distintos da semana
- ✅ Exibir ficha como checklist interativo para aluno
- ✅ Duplicar e editar fichas existentes
- ✅ Consultar histórico de fichas

### Por Quê?
O OmniConnect precisa de um sistema robusto de fichas de treino pois:
- Personal/Professor precisa organizar treinos de forma estruturada
- Aluno precisa visualizar e executar treinos com clareza
- Sistema deve suportar diferentes fichas por dia da semana
- Histórico é essencial para acompanhar progressão

### Escopo
✅ **Incluído neste PRD:**
- Criar nova ficha de treino com exercícios
- Listar fichas de treino (do aluno ou pessoal)
- Buscar ficha por ID
- Atualizar ficha (editar exercícios)
- Deletar ficha
- Organizar exercícios por grupos musculares
- Visualizar ficha como checklist (aluno marca como feito)
- Duplicar ficha existente

❌ **NÃO incluído (futuro PRD):**
- Análise de IA sobre treino
- Sugestões automáticas de carga
- Integração com Logbook (será separado)
- Notificações de treino

---

## 📊 2. Especificação Técnica

### 2.1 Modelo de Dados

#### Tabela: WorkoutSheet (Ficha de Treino)
```python
class WorkoutSheet(Base):
    """Ficha de treino do aluno"""
    
    __tablename__ = "workout_sheets"
    
    id: UUID                      # Identificador único
    user_id: UUID                 # Aluno que receberá a ficha (FK Users)
    personal_trainer_id: UUID     # Personal que criou (FK Users)
    name: str                     # Nome da ficha (ex: "Treino A - Peito")
    description: str              # Descrição (opcional)
    day_of_week: int              # Dia da semana (0=seg, 1=ter, ..., 6=dom)
    is_active: bool               # Ficha está ativa?
    created_at: datetime          # Data de criação
    updated_at: datetime          # Data da última atualização
    exercises: List[Exercise]     # Relação 1:N com exercícios
```

#### Tabela: Exercise (Exercício da Ficha)
```python
class Exercise(Base):
    """Exercício dentro de uma ficha de treino"""
    
    __tablename__ = "exercises"
    
    id: UUID                      # Identificador único
    workout_sheet_id: UUID        # Ficha de treino (FK WorkoutSheets)
    name: str                     # Nome do exercício (ex: "Supino Reto")
    muscle_group: str             # Grupo muscular (peito, costa, perna, etc)
    series: int                   # Número de séries
    repetitions: int              # Número de repetições
    load_kg: float                # Carga em KG (sugerida)
    rest_seconds: int             # Descanso entre séries (segundos)
    observations: str             # Observações (técnica, respiração, etc)
    image_url: str                # URL da imagem (opcional)
    gif_url: str                  # URL do GIF demonstrativo (opcional)
    order: int                    # Ordem de execução (1, 2, 3...)
    created_at: datetime
    updated_at: datetime
```

#### Tabela: ChecklistItem (Registro de Execução)
```python
class ChecklistItem(Base):
    """Registro de execução de um exercício (opcional para MVP)"""
    
    __tablename__ = "checklist_items"
    
    id: UUID
    exercise_id: UUID             # Exercício (FK Exercises)
    date: datetime                # Data da execução
    completed: bool               # Foi completado?
    actual_series: int            # Séries realizadas
    actual_repetitions: int       # Repetições realizadas
    actual_load_kg: float         # Carga real utilizada
    notes: str                    # Notas do aluno
```

### 2.2 DTOs (Data Transfer Objects)

#### ExerciseDTO (Exercício dentro da ficha)
```json
{
  "name": "Supino Reto",
  "muscle_group": "peito",
  "series": 4,
  "repetitions": 8,
  "load_kg": 80.0,
  "rest_seconds": 120,
  "observations": "Manter scapula retraída, evitar cambota",
  "image_url": "https://cdn.example.com/exercises/supino-reto.jpg",
  "gif_url": "https://cdn.example.com/exercises/supino-reto.gif",
  "order": 1
}
```

**Validações:**
- ✅ `name`: Obrigatório, máx 255 caracteres
- ✅ `muscle_group`: Obrigatório, lista pré-definida
- ✅ `series`: Obrigatório, > 0
- ✅ `repetitions`: Obrigatório, > 0
- ✅ `load_kg`: Obrigatório, > 0
- ✅ `rest_seconds`: Obrigatório, ≥ 0
- ✅ `image_url`: Opcional, URL válida
- ✅ `gif_url`: Opcional, URL válida

#### CreateWorkoutSheetDTO
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Treino A - Peito",
  "description": "Ficha de peito com foco em força",
  "day_of_week": 0,
  "exercises": [
    { "name": "Supino Reto", "muscle_group": "peito", "series": 4, ... },
    { "name": "Supino Inclinado", "muscle_group": "peito", "series": 3, ... }
  ]
}
```

#### UpdateWorkoutSheetDTO (Todos campos opcionais)
```json
{
  "name": "Treino A - Peito Modificado",
  "description": "Nova descrição",
  "day_of_week": 0,
  "exercises": [ ... ]  # Se vazio, mantém exercícios atuais
}
```

#### WorkoutSheetResponseDTO
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "personal_trainer_id": "550e8400-e29b-41d4-a716-446655440002",
  "name": "Treino A - Peito",
  "description": "Ficha de peito com foco em força",
  "day_of_week": 0,
  "is_active": true,
  "created_at": "2026-04-19T10:30:00Z",
  "updated_at": "2026-04-19T10:30:00Z",
  "exercises": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440010",
      "name": "Supino Reto",
      "muscle_group": "peito",
      "series": 4,
      "repetitions": 8,
      "load_kg": 80.0,
      "rest_seconds": 120,
      "observations": "Manter scapula retraída",
      "image_url": "https://...",
      "gif_url": "https://...",
      "order": 1
    },
    ...
  ]
}
```

---

## 🔌 3. Endpoints HTTP

### 3.1 POST /api/v1/workout-sheets (Criar ficha de treino)

**Descrição:** Personal/Professor cria nova ficha de treino

**Request:**
```http
POST /api/v1/workout-sheets HTTP/1.1
Content-Type: application/json
Authorization: Bearer {token}

{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Treino A - Peito",
  "description": "Ficha de peito com foco em força",
  "day_of_week": 0,
  "exercises": [
    {
      "name": "Supino Reto",
      "muscle_group": "peito",
      "series": 4,
      "repetitions": 8,
      "load_kg": 80.0,
      "rest_seconds": 120,
      "observations": "Manter scapula retraída"
    }
  ]
}
```

**Response 201 (Sucesso):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "personal_trainer_id": "550e8400-e29b-41d4-a716-446655440002",
  "name": "Treino A - Peito",
  "description": "Ficha de peito com foco em força",
  "day_of_week": 0,
  "is_active": true,
  "created_at": "2026-04-19T10:30:00Z",
  "updated_at": "2026-04-19T10:30:00Z",
  "exercises": [...]
}
```

**Response 400 (Validação):**
```json
{
  "detail": "Usuário (aluno) não encontrado"
}
```

---

### 3.2 GET /api/v1/workout-sheets (Listar fichas)

**Descrição:** Listar fichas do usuário autenticado (com filtros)

**Request:**
```http
GET /api/v1/workout-sheets?user_id=550e8400-e29b-41d4-a716-446655440000&page=1&limit=10 HTTP/1.1
Authorization: Bearer {token}
```

**Query Parameters:**
- `user_id`: (Opcional) Filtrar por aluno - só admin/personal pode usar
- `day_of_week`: (Opcional) Filtrar por dia (0-6)
- `page`: Página (padrão: 1)
- `limit`: Itens por página (padrão: 10, máximo: 100)

**Response 200:**
```json
{
  "total": 5,
  "page": 1,
  "limit": 10,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "personal_trainer_id": "550e8400-e29b-41d4-a716-446655440002",
      "name": "Treino A - Peito",
      "day_of_week": 0,
      "is_active": true,
      "exercise_count": 3,
      "created_at": "2026-04-19T10:30:00Z"
    }
  ]
}
```

---

### 3.3 GET /api/v1/workout-sheets/{id} (Buscar ficha)

**Descrição:** Retorna ficha com todos seus exercícios

**Request:**
```http
GET /api/v1/workout-sheets/550e8400-e29b-41d4-a716-446655440001 HTTP/1.1
Authorization: Bearer {token}
```

**Response 200:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "personal_trainer_id": "550e8400-e29b-41d4-a716-446655440002",
  "name": "Treino A - Peito",
  "description": "Ficha de peito com foco em força",
  "day_of_week": 0,
  "is_active": true,
  "created_at": "2026-04-19T10:30:00Z",
  "updated_at": "2026-04-19T10:30:00Z",
  "exercises": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440010",
      "name": "Supino Reto",
      "muscle_group": "peito",
      "series": 4,
      "repetitions": 8,
      "load_kg": 80.0,
      "rest_seconds": 120,
      "observations": "Manter scapula retraída",
      "image_url": "https://...",
      "gif_url": "https://...",
      "order": 1
    }
  ]
}
```

**Response 404:**
```json
{
  "detail": "Ficha de treino não encontrada"
}
```

---

### 3.4 PUT /api/v1/workout-sheets/{id} (Atualizar ficha)

**Descrição:** Editar ficha (nome, descrição, exercícios)

**Request:**
```http
PUT /api/v1/workout-sheets/550e8400-e29b-41d4-a716-446655440001 HTTP/1.1
Content-Type: application/json
Authorization: Bearer {token}

{
  "name": "Treino A - Peito (Modificado)",
  "exercises": [
    { "name": "Supino Reto", "muscle_group": "peito", "series": 5, ... },
    { "name": "Novo Exercício", "muscle_group": "peito", "series": 3, ... }
  ]
}
```

**Response 200:** Ficha atualizada

**Response 404:**
```json
{
  "detail": "Ficha de treino não encontrada"
}
```

---

### 3.5 DELETE /api/v1/workout-sheets/{id} (Deletar ficha)

**Descrição:** Remove ficha (soft delete - marca como inativa)

**Request:**
```http
DELETE /api/v1/workout-sheets/550e8400-e29b-41d4-a716-446655440001 HTTP/1.1
Authorization: Bearer {token}
```

**Response 204 (Sem conteúdo):**
```
(sem body)
```

---

### 3.6 POST /api/v1/workout-sheets/{id}/duplicate (Duplicar ficha)

**Descrição:** Cria uma cópia de uma ficha existente

**Request:**
```http
POST /api/v1/workout-sheets/550e8400-e29b-41d4-a716-446655440001/duplicate HTTP/1.1
Content-Type: application/json
Authorization: Bearer {token}

{
  "name": "Treino A - Peito (Cópia)",
  "user_id": "550e8400-e29b-41d4-a716-446655440000"  # Opcional, padrão é mesma ficha
}
```

**Response 201:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440099",
  "name": "Treino A - Peito (Cópia)",
  "exercises": [ ... ]  # Mesmos exercícios
}
```

---

## 🔐 4. Requisitos de Segurança

### 4.1 Controle de Acesso
- ✅ Personal/Professor pode criar/editar/deletar SUAS fichas
- ✅ Admin pode gerenciar fichas de qualquer aluno
- ✅ Aluno pode visualizar SUAS fichas, não pode editar
- ✅ Aluno não pode ver fichas de outros alunos

### 4.2 Validações
- ✅ Exercícios devem ter séries, repetições e carga > 0
- ✅ URLs de imagem devem ser válidas
- ✅ Grupos musculares deve ser de lista pré-definida

### 4.3 Grupo Muscular Válidos
```python
VALID_MUSCLE_GROUPS = {
    "peito",
    "costa",
    "ombro",
    "bíceps",
    "tríceps",
    "antebraço",
    "core",
    "perna_anterior",
    "perna_posterior",
    "panturrilha",
}
```

---

## 🧪 5. Testes Automatizados

### 5.1 Testes de Integração (test_workout_sheets.py)

**Teste 1: Criar ficha com exercícios válidos**
- Deve retornar 201
- Ficha deve ter ID único
- Exercícios devem ser salvos com ordem correta

**Teste 2: Listar fichas do usuário**
- Deve retornar 200 com paginação
- Apenas fichas do usuário/personal
- Suportar filtro por dia_semana

**Teste 3: Buscar ficha por ID com exercícios**
- Deve retornar 200
- Exercícios devem estar em ordem
- Incluir todas as informações

**Teste 4: Atualizar ficha (editar exercícios)**
- Deve retornar 200
- Exercícios antigos devem ser removidos
- Novos exercícios devem ser adicionados

**Teste 5: Deletar ficha**
- Deve retornar 204
- Ficha não deve mais aparecer em listagens
- Soft delete - manter no banco com is_active=False

**Teste 6: Duplicar ficha**
- Deve retornar 201
- Nova ficha deve ter novo ID
- Exercícios devem ser idênticos
- Pode ter novo nome/usuário

**Teste 7: Validação de grupos musculares**
- Deve rejeitar grupo inválido (422)

**Teste 8: Validação de séries/reps/carga > 0**
- Deve rejeitar valores <= 0 (422)

**Teste 9: Controle de acesso**
- Aluno não pode editar ficha (403)
- Personal só vê suas fichas (200 mas filtrado)

### 5.2 Testes Unitários

**test_workout_sheet_dto.py:**
- DTOs válidos devem passar
- DTOs inválidos devem falhar

**test_workout_sheet_service.py:**
- Lógica de duplicação
- Validação de exercícios
- Controle de permissões

---

## 📋 6. Critérios de Aceitação

### User Story 1: Personal Cria Ficha com Exercícios
```
DADO que um Personal está na app
QUANDO ele vai criar nova ficha
ENTÃO pode adicionar múltiplos exercícios por ficha
E cada exercício tem nome, séries, reps, carga, grupo muscular
E recebe resposta 201 com ficha completa
```

### User Story 2: Aluno Visualiza Ficha
```
DADO que uma ficha foi atribuída ao aluno
QUANDO ele acessa GET /api/v1/workout-sheets/{id}
ENTÃO vê todos os exercícios em ordem
E tem acesso a imagem/GIF de cada exercício
E pode usar como checklist durante treino
```

### User Story 3: Editar Ficha Existente
```
DADO que Personal quer modificar ficha existente
QUANDO acessa PUT /api/v1/workout-sheets/{id}
ENTÃO pode adicionar/remover/editar exercícios
E updated_at é atualizado
E aluno vê mudanças imediatamente
```

### User Story 4: Duplicar Ficha
```
DADO que Personal tem ficha "Treino A"
QUANDO clica em "Duplicar"
ENTÃO cria nova ficha com mesmo exercícios
E pode renomear/reatribuir
E original não é afetada
```

### User Story 5: Controle de Acesso
```
DADO que um aluno tenta editar ficha
QUANDO faz PUT /api/v1/workout-sheets/{id}
ENTÃO recebe erro 403 Forbidden
E aluno pode apenas VISUALIZAR fichas, não editar
```

---

## 📁 7. Arquivos a Criar

```
backend/
├── app/
│   ├── models/
│   │   ├── workout_sheet.py      # Model WorkoutSheet + Exercise
│   │   └── checklist_item.py     # Model ChecklistItem (futuro)
│   ├── dtos/
│   │   └── workout_sheet_dto.py  # DTOs
│   ├── services/
│   │   └── workout_sheet_service.py
│   ├── repositories/
│   │   └── workout_sheet_repository.py
│   ├── controllers/
│   │   └── workout_sheet_controller.py
│   └── routes/
│       └── workout_sheet.py
├── tests/
│   ├── test_workout_sheets.py    # Integração
│   └── unit/
│       ├── test_workout_sheet_dto.py
│       ├── test_workout_sheet_service.py
│       └── test_workout_sheet_repository.py
└── main.py                        # Registrar rota
```

---

## ⚡ 8. Ordem de Implementação

### Fase 1: Estrutura Base (1-2h)
```
1. Criar models/workout_sheet.py (WorkoutSheet + Exercise)
2. Criar dtos/workout_sheet_dto.py
```

### Fase 2: Lógica de Negócio (1-2h)
```
3. Criar repositories/workout_sheet_repository.py
4. Criar services/workout_sheet_service.py
```

### Fase 3: API (1-2h)
```
5. Criar controllers/workout_sheet_controller.py
6. Criar routes/workout_sheet.py (6 endpoints)
7. Registrar em main.py
```

### Fase 4: Testes (2-3h)
```
8. Criar tests/test_workout_sheets.py (9+ testes)
9. Criar tests/unit/* (unitários)
10. Validar cobertura > 80%
```

---

## 🎯 9. Definição de Pronto ("Done")

Módulo está **pronto** quando:

- ✅ Todos os 6 endpoints funcionam (`POST`, `GET /`, `GET /{id}`, `PUT`, `DELETE`, `POST /duplicate`)
- ✅ Personal pode criar fichas com múltiplos exercícios
- ✅ Aluno pode visualizar fichas (read-only)
- ✅ Exercícios são salvos com ordem correta
- ✅ Suporta grupos musculares válidos
- ✅ Testes de integração: **9+ testes passando**
- ✅ Testes unitários: **5+ testes passando**
- ✅ Cobertura de testes: **≥ 80%**
- ✅ Documentação automática no Swagger (`/docs`)
- ✅ Controle de acesso (aluno read-only, personal full)
- ✅ Soft delete (marcar is_active=False)

---

## 📊 10. Requisitos Mapeados do PDF

| Requisito | ID | Status |
|-----------|-----|--------|
| Personal pode criar fichas com múltiplos exercícios | RF-08 | ✅ Implementar |
| Cada exercício com nome, séries, reps, carga, descanso | RF-09 | ✅ Implementar |
| Suporte a imagem/GIF demonstrativo | RF-10 | ✅ Implementar |
| Ficha como checklist interativo | RF-11 | ⏳ MVP 2 |
| Atribuir fichas diferentes para dias distintos | RF-12 | ✅ Implementar |
| Duplicar e editar fichas | RF-13 | ✅ Implementar |
| Histórico de fichas | RF-14 | ✅ Implementar |

---

## 💼 11. Regras de Negócio Aplicáveis

| Regra | Impacto |
|-------|--------|
| RN-02: Só Personal/Professor/Gestor podem criar fichas | Validação em controller |
| RN-03: Validação com base em logbook do aluno | Fase 2 (integração com logbook) |
| RN-01: Um aluno só pode ter uma ficha ativa por dia | Validação ao criar |

---

## 📝 Notas Finais

**PRD Completo?** Sim, cobrir requisitos, testes, segurança, endpoints, DTOs.

**Próximas Fases:** 
- Fase 2: Integração com Logbook + Checklist de Execução
- Fase 3: Análise de IA sobre progressão

---

*Criado para: OmniConnect Fitness - Alpha EdTech*  
*Arquitetura: FastAPI + SQLAlchemy + PostgreSQL*  
*Baseado em: Requisitos_OmniConnect_Fitness.pdf (Seção 3.2)*
