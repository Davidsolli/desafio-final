# PRD: Logbook (Diário de Treino) - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-04-21  
**Status:** 📋 Em Especificação
**Responsável:** José Henrique.

---

## 📋 1. Visão Geral

### Objetivo
Criar um sistema completo de registro de treinos (logbook/diário) que permita:
- ✅ Aluno registrar pesos, séries e repetições efetivamente executadas
- ✅ Logbook vinculado à ficha de treino ativa, pré-populando exercícios
- ✅ Sistema calcular e exibir evolução de carga ao longo do tempo
- ✅ Aluno adicionar notas livres (texto) a cada sessão
- ✅ Personal ter acesso de leitura ao logbook dos alunos
- ✅ Exibir calendário com dias de treino realizados e não realizados
- ✅ Histórico completo e auditável de todas as sessões

### Por Quê?
O OmniConnect precisa de um logbook robusto pois:
- **Rastreamento:** Sem histórico, não conseguimos acompanhar progressão do aluno
- **Base para IA:** Análise de IA depende de dados históricos confiáveis (RF-21 a RF-26)
- **Validação:** Personal precisa confirmar execução antes de contar como válida
- **Motivação:** Aluno vê progresso (carga crescente) = motivação contínua
- **Evidência:** Serve como prova de treino para ajuite de carga/volume futuro

### Escopo
✅ **Incluído neste PRD:**
- Registrar sessão de treino com exercícios executados
- Capturar pesos, séries, repetições REAIS vs. planejado
- Notas de observação por exercício
- Notas gerais da sessão (como se sentiu, observações)
- Vinculação automática com ficha ativa
- Histórico e auditoria completa
- Visualização de evolução de carga
- Calendário de treinos (realizados vs. faltados)
- Permissões por role (aluno edita próximo a sessão, personal lê)

❌ **NÃO incluído (futuro PRD):**
- Análise de IA sobre padrões (RF-21 - será PRD_ANALISA_IA.md)
- Sugestões de carga (RF-22 - será PRD_ANALISA_IA.md)
- Detecção de estagnação (RF-23 - será PRD_ANALISA_IA.md)
- Integração com wearables/smartwatch
- Backup automático de fotos durante treino

---

## 📊 2. Especificação Técnica

### 2.1 Modelo de Dados

#### Tabela: WorkoutSession (Sessão de Treino)
```python
class WorkoutSession(Base):
    """Sessão de treino registrada pelo aluno"""
    
    __tablename__ = "workout_sessions"
    
    id: UUID                      # Identificador único
    user_id: UUID                 # Aluno que realizou (FK Users)
    workout_sheet_id: UUID        # Ficha de treino usada (FK WorkoutSheets)
    session_date: datetime        # Data/hora em que treinou
    
    # Status da sessão
    status: str                   # "completed", "incomplete", "skipped"
                                  # completed = finalizou
                                  # incomplete = começou mas não terminou
                                  # skipped = dia que deveria treinar mas não fez
    
    # Observações gerais
    general_notes: str            # Notas sobre como se sentiu, observações
    difficulty_level: int         # 1-10: Quanto de dificuldade foi (subjetivo)
    mood: str                     # "great", "good", "normal", "bad", "terrible"
    
    # Rastreamento
    created_at: datetime          # Quando criou registro
    updated_at: datetime          # Última atualização
    completed_at: datetime        # Quando finalizou (NULL se não completado)
    
    # Auditoria
    approved_by_personal_id: UUID # Personal que aprovou (nullable, futuro)
    approved_at: datetime         # Quando foi aprovado
    
    # Relações
    session_exercises: List[SessionExercise]  # Exercícios executados
```

#### Tabela: SessionExercise (Exercício na Sessão)
```python
class SessionExercise(Base):
    """Um exercício dentro de uma sessão registrada"""
    
    __tablename__ = "session_exercises"
    
    id: UUID                      # Identificador único
    session_id: UUID              # Sessão (FK WorkoutSessions)
    exercise_id: UUID             # Exercício planejado (FK Exercises)
    
    # O que estava planejado
    planned_series: int           # Séries planejadas
    planned_repetitions: int      # Repetições planejadas
    planned_load_kg: float        # Carga planejada
    
    # O que foi realmente executado
    actual_series: int            # Séries realmente feitas
    actual_repetitions: int       # Repetições realmente feitas (por série)
    actual_load_kg: float         # Carga realmente usada
    
    # Detalhes por série (opcional - pode ser expandido depois)
    series_details: JSON          # Ex: [
                                  #   {"series": 1, "reps": 8, "load": 80},
                                  #   {"series": 2, "reps": 8, "load": 80},
                                  #   {"series": 3, "reps": 6, "load": 85}
                                  # ]
    
    # Observações
    exercise_notes: str           # Notas específicas do exercício
    pain_or_discomfort: bool      # Sentiu dor/desconforto?
    pain_description: str         # Se sim, descrever
    modification: str             # Se adaptou o exercício, como?
    
    # Status
    status: str                   # "completed", "partial", "skipped"
    
    created_at: datetime
    updated_at: datetime
```

#### Tabela: ExerciseProgression (Para cálculos de evolução)
```python
class ExerciseProgression(Base):
    """View/Cache para evolução de um exercício (gerada via query)"""
    # Não é uma tabela física, mas uma VIEW ou cache
    # Usada para otimizar queries de histórico
    
    # SELECT 
    #   e.id,
    #   se.session_id,
    #   ws.session_date,
    #   MAX(se.actual_load_kg) as max_load,
    #   AVG(se.actual_load_kg) as avg_load,
    #   COUNT(*) as volume,
    #   ROW_NUMBER() OVER (ORDER BY ws.session_date) as week_number
    # FROM exercises e
    # JOIN session_exercises se ON se.exercise_id = e.id
    # JOIN workout_sessions ws ON ws.id = se.session_id
    # WHERE e.id = $1 AND ws.user_id = $2
    # GROUP BY WEEK(ws.session_date)
```

---

### 2.2 DTOs (Data Transfer Objects)

#### CreateSessionDTO (Iniciar/Criar Sessão)
```json
{
  "workout_sheet_id": "550e8400-e29b-41d4-a716-446655440001",
  "session_date": "2026-04-21T18:30:00Z"
}
```

**Validações:**
- ✅ `workout_sheet_id`: UUID válido, ficha existe e está ativa
- ✅ `session_date`: Data no passado ou presente, não futuro
- ✅ Verificar se aluno só pode ter 1 sessão em progresso por vez

#### SessionExerciseDTO (Exercício na Sessão - Input)
```json
{
  "exercise_id": "550e8400-e29b-41d4-a716-446655440010",
  "actual_series": 4,
  "actual_repetitions": 8,
  "actual_load_kg": 80.0,
  "series_details": [
    {"series": 1, "reps": 8, "load": 80},
    {"series": 2, "reps": 8, "load": 80},
    {"series": 3, "reps": 7, "load": 80},
    {"series": 4, "reps": 6, "load": 80}
  ],
  "exercise_notes": "Sentiu aperto no ombro na 3ª série",
  "pain_or_discomfort": true,
  "pain_description": "Aperto leve no ombro anterior",
  "modification": "Reduzi amplitude de movimento",
  "status": "completed"
}
```

**Validações:**
- ✅ `exercise_id`: UUID válido, exercício existe
- ✅ `actual_series`: > 0
- ✅ `actual_repetitions`: > 0
- ✅ `actual_load_kg`: > 0
- ✅ `status`: enum ["completed", "partial", "skipped"]
- ✅ `pain_description`: obrigatório se `pain_or_discomfort` = true

#### CompleteSessionDTO (Finalizar Sessão)
```json
{
  "session_exercises": [
    { "exercise_id": "...", "actual_series": 4, "actual_repetitions": 8, ... },
    { "exercise_id": "...", "actual_series": 3, "actual_repetitions": 10, ... }
  ],
  "general_notes": "Treino muito bom, senti forte em todo",
  "difficulty_level": 7,
  "mood": "great",
  "status": "completed"
}
```

#### SessionResponseDTO (Saída - Sessão Completa)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440020",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "workout_sheet_id": "550e8400-e29b-41d4-a716-446655440001",
  "session_date": "2026-04-21T18:30:00Z",
  "status": "completed",
  "general_notes": "Treino muito bom",
  "difficulty_level": 7,
  "mood": "great",
  "created_at": "2026-04-21T19:00:00Z",
  "updated_at": "2026-04-21T19:45:00Z",
  "completed_at": "2026-04-21T19:45:00Z",
  "session_exercises": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440021",
      "exercise_id": "550e8400-e29b-41d4-a716-446655440010",
      "exercise_name": "Supino Reto",
      "muscle_group": "peito",
      "planned_series": 4,
      "planned_repetitions": 8,
      "planned_load_kg": 80.0,
      "actual_series": 4,
      "actual_repetitions": 8,
      "actual_load_kg": 80.0,
      "series_details": [ ... ],
      "exercise_notes": "Sentiu aperto no ombro na 3ª série",
      "pain_or_discomfort": true,
      "pain_description": "Aperto leve no ombro anterior",
      "modification": "Reduzi amplitude de movimento",
      "status": "completed"
    }
  ]
}
```

#### ProgressionDTO (Evolução de Exercício)
```json
{
  "exercise_id": "550e8400-e29b-41d4-a716-446655440010",
  "exercise_name": "Supino Reto",
  "data_points": [
    {
      "session_date": "2026-04-01T18:30:00Z",
      "actual_load_kg": 75.0,
      "actual_series": 4,
      "actual_repetitions": 8,
      "volume_kg": 2400  # 4 séries * 8 reps * 75kg
    },
    {
      "session_date": "2026-04-08T18:30:00Z",
      "actual_load_kg": 77.5,
      "actual_series": 4,
      "actual_repetitions": 8,
      "volume_kg": 2480
    },
    {
      "session_date": "2026-04-15T18:30:00Z",
      "actual_load_kg": 80.0,
      "actual_series": 4,
      "actual_repetitions": 8,
      "volume_kg": 2560
    }
  ],
  "trend": "increasing",
  "avg_load_kg": 77.5,
  "max_load_kg": 80.0,
  "min_load_kg": 75.0,
  "total_sessions": 3
}
```

---

## 🔌 3. Endpoints HTTP

### 3.1 POST /api/v1/logbook/sessions (Iniciar Sessão)

**Descrição:** Aluno inicia novo registro de treino vinculado à ficha ativa

**Request:**
```http
POST /api/v1/logbook/sessions HTTP/1.1
Content-Type: application/json
Authorization: Bearer {token}

{
  "workout_sheet_id": "550e8400-e29b-41d4-a716-446655440001",
  "session_date": "2026-04-21T18:30:00Z"
}
```

**Response 201 (Sucesso):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440020",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "workout_sheet_id": "550e8400-e29b-41d4-a716-446655440001",
  "session_date": "2026-04-21T18:30:00Z",
  "status": "in_progress",
  "session_exercises": []
}
```

**Response 400 (Validação):**
```json
{
  "detail": "Ficha de treino não encontrada ou inativa"
}
```

**Response 409 (Conflito):**
```json
{
  "detail": "Já existe uma sessão em progresso. Finalize-a primeiro."
}
```

---

### 3.2 POST /api/v1/logbook/sessions/{id}/exercises (Adicionar/Atualizar Exercício)

**Descrição:** Registrar um exercício executado na sessão atual

**Request:**
```http
POST /api/v1/logbook/sessions/550e8400-e29b-41d4-a716-446655440020/exercises HTTP/1.1
Content-Type: application/json
Authorization: Bearer {token}

{
  "exercise_id": "550e8400-e29b-41d4-a716-446655440010",
  "actual_series": 4,
  "actual_repetitions": 8,
  "actual_load_kg": 80.0,
  "series_details": [
    {"series": 1, "reps": 8, "load": 80},
    {"series": 2, "reps": 8, "load": 80},
    {"series": 3, "reps": 7, "load": 80},
    {"series": 4, "reps": 6, "load": 80}
  ],
  "exercise_notes": "Sentiu aperto no ombro",
  "pain_or_discomfort": true,
  "pain_description": "Aperto leve anterior",
  "modification": "Reduzi amplitude",
  "status": "completed"
}
```

**Response 201 (Criado) ou 200 (Atualizado):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440021",
  "session_id": "550e8400-e29b-41d4-a716-446655440020",
  "exercise_id": "550e8400-e29b-41d4-a716-446655440010",
  "exercise_name": "Supino Reto",
  "planned_series": 4,
  "planned_repetitions": 8,
  "planned_load_kg": 80.0,
  "actual_series": 4,
  "actual_repetitions": 8,
  "actual_load_kg": 80.0,
  "series_details": [ ... ],
  "exercise_notes": "Sentiu aperto no ombro",
  "pain_or_discomfort": true,
  "status": "completed"
}
```

---

### 3.3 PUT /api/v1/logbook/sessions/{id} (Finalizar Sessão)

**Descrição:** Finalizar registro de treino com todos os exercícios

**Request:**
```http
PUT /api/v1/logbook/sessions/550e8400-e29b-41d4-a716-446655440020 HTTP/1.1
Content-Type: application/json
Authorization: Bearer {token}

{
  "general_notes": "Treino muito bom, senti forte",
  "difficulty_level": 7,
  "mood": "great",
  "status": "completed"
}
```

**Response 200:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440020",
  "status": "completed",
  "completed_at": "2026-04-21T19:45:00Z",
  "session_exercises": [ ... ]
}
```

---

### 3.4 GET /api/v1/logbook/sessions (Listar Sessões)

**Descrição:** Listar histórico de sessões (com filtros)

**Request:**
```http
GET /api/v1/logbook/sessions?user_id=550e8400...&start_date=2026-04-01&end_date=2026-04-21&page=1&limit=10 HTTP/1.1
Authorization: Bearer {token}
```

**Query Parameters:**
- `user_id`: (Opcional) Apenas admin/personal pode filtrar por aluno específico
- `start_date`: (Opcional) Filtrar por data inicial
- `end_date`: (Opcional) Filtrar por data final
- `status`: (Opcional) "completed", "incomplete", "skipped"
- `page`: Página (padrão: 1)
- `limit`: Itens por página (padrão: 10, máximo: 100)

**Response 200:**
```json
{
  "total": 15,
  "page": 1,
  "limit": 10,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440020",
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "workout_sheet_id": "550e8400-e29b-41d4-a716-446655440001",
      "session_date": "2026-04-21T18:30:00Z",
      "status": "completed",
      "difficulty_level": 7,
      "mood": "great",
      "exercise_count": 5,
      "completed_at": "2026-04-21T19:45:00Z",
      "created_at": "2026-04-21T19:00:00Z"
    }
  ]
}
```

---

### 3.5 GET /api/v1/logbook/sessions/{id} (Buscar Sessão)

**Descrição:** Retorna sessão com todos os exercícios registrados

**Request:**
```http
GET /api/v1/logbook/sessions/550e8400-e29b-41d4-a716-446655440020 HTTP/1.1
Authorization: Bearer {token}
```

**Response 200:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440020",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "workout_sheet_id": "550e8400-e29b-41d4-a716-446655440001",
  "session_date": "2026-04-21T18:30:00Z",
  "status": "completed",
  "general_notes": "Treino muito bom",
  "difficulty_level": 7,
  "mood": "great",
  "created_at": "2026-04-21T19:00:00Z",
  "updated_at": "2026-04-21T19:45:00Z",
  "completed_at": "2026-04-21T19:45:00Z",
  "session_exercises": [ 
    { ... exercício 1 ... },
    { ... exercício 2 ... }
  ]
}
```

**Response 404:**
```json
{
  "detail": "Sessão de treino não encontrada"
}
```

---

### 3.6 GET /api/v1/logbook/calendar (Calendário de Treinos)

**Descrição:** Retorna calendário com dias de treino realizados vs. faltados

**Request:**
```http
GET /api/v1/logbook/calendar?year=2026&month=4&user_id=550e8400... HTTP/1.1
Authorization: Bearer {token}
```

**Response 200:**
```json
{
  "year": 2026,
  "month": 4,
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "days": [
    {
      "date": "2026-04-01",
      "day_of_week": 3,
      "status": "completed",
      "session_id": "550e8400-e29b-41d4-a716-446655440020",
      "exercise_count": 5
    },
    {
      "date": "2026-04-02",
      "day_of_week": 4,
      "status": "skipped",
      "session_id": null
    },
    {
      "date": "2026-04-03",
      "day_of_week": 5,
      "status": "no_plan",
      "session_id": null
    }
  ],
  "summary": {
    "completed": 12,
    "incomplete": 1,
    "skipped": 2,
    "no_plan": 15
  }
}
```

---

### 3.7 GET /api/v1/logbook/progression/{exercise_id} (Evolução de Exercício)

**Descrição:** Retorna histórico de evolução de carga de um exercício

**Request:**
```http
GET /api/v1/logbook/progression/550e8400-e29b-41d4-a716-446655440010?user_id=550e8400...&weeks=12 HTTP/1.1
Authorization: Bearer {token}
```

**Query Parameters:**
- `user_id`: (Opcional) Admin/personal pode ver alunos específicos
- `weeks`: (Opcional) Últimas N semanas (padrão: 4)
- `start_date`: (Opcional) Data inicial
- `end_date`: (Opcional) Data final

**Response 200:**
```json
{
  "exercise_id": "550e8400-e29b-41d4-a716-446655440010",
  "exercise_name": "Supino Reto",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "data_points": [
    {
      "session_date": "2026-04-01T18:30:00Z",
      "actual_load_kg": 75.0,
      "actual_series": 4,
      "actual_repetitions": 8,
      "volume_kg": 2400
    },
    {
      "session_date": "2026-04-08T18:30:00Z",
      "actual_load_kg": 77.5,
      "actual_series": 4,
      "actual_repetitions": 8,
      "volume_kg": 2480
    },
    {
      "session_date": "2026-04-15T18:30:00Z",
      "actual_load_kg": 80.0,
      "actual_series": 4,
      "actual_repetitions": 8,
      "volume_kg": 2560
    }
  ],
  "statistics": {
    "total_sessions": 3,
    "avg_load_kg": 77.5,
    "max_load_kg": 80.0,
    "min_load_kg": 75.0,
    "avg_volume_kg": 2480,
    "trend": "increasing",
    "improvement_percentage": 6.67
  }
}
```

---

### 3.8 DELETE /api/v1/logbook/sessions/{id} (Deletar Sessão)

**Descrição:** Remove uma sessão (soft delete - marca como deleted)

**Request:**
```http
DELETE /api/v1/logbook/sessions/550e8400-e29b-41d4-a716-446655440020 HTTP/1.1
Authorization: Bearer {token}
```

**Response 204 (Sem conteúdo):**
```
(sem body)
```

**Response 404:**
```json
{
  "detail": "Sessão não encontrada"
}
```

⚠️ **Nota:** Aluno só pode deletar sessão se foi criador. Personal/Gestor pode auditar mas não deletar (apenas soft delete).

---

## 🔐 4. Requisitos de Segurança

### 4.1 Controle de Acesso
- ✅ Aluno pode criar/editar/deletar SUAS sessões
- ✅ Aluno só edita sua sessão (não de outros alunos)
- ✅ Personal pode VISUALIZAR (read-only) logbook dos seus alunos
- ✅ Personal NÃO pode editar sessão do aluno (apenas ler/análise)
- ✅ Admin pode visualizar logbook de qualquer aluno
- ✅ Aluno NÃO pode ver logbook de outros alunos

### 4.2 Validações
- ✅ `session_date`: Não pode ser data futura
- ✅ `session_date`: Não pode ser anterior a criação da ficha
- ✅ Séries, reps, carga devem ser > 0
- ✅ `actual_load_kg` não pode ser negativo
- ✅ `difficulty_level`: 1-10
- ✅ `mood`: enum válido
- ✅ Aluno só pode ter 1 sessão "in_progress" por vez

### 4.3 Auditoria
- ✅ Todos os campos `created_at`, `updated_at` são immutáveis
- ✅ Histórico de mudanças rastreável (soft delete, não hard delete)
- ✅ Dados sensíveis (dor, modificações) não devem ser expostos sem autorização
- ✅ Logs devem incluir user_id de quem alterou

### 4.4 Privacidade
- ✅ Notas pessoais do aluno visíveis apenas para aluno e seu(s) personal(is)
- ✅ Dados não podem ser exportados sem consentimento
- ✅ LGPD: Aluno pode pedir exclusão de sessão (soft delete)

---

## 🧪 5. Testes Automatizados

### 5.1 Testes de Integração (test_logbook_sessions.py)

**Teste 1: Criar sessão com sucesso**
- ✅ POST /sessions com ficha_id válida
- ✅ Retorna 201 com ID único
- ✅ Status inicia como "in_progress"
- ✅ Exercícios vazios (será preenchido depois)

**Teste 2: Não pode criar sessão se já tem uma em progresso**
- ✅ Criar primeira sessão
- ✅ Tentar criar segunda antes de finalizar
- ✅ Retorna 409 "Já existe sessão em progresso"

**Teste 3: Adicionar exercício à sessão**
- ✅ POST /sessions/{id}/exercises com dados válidos
- ✅ Retorna 201 com exercício registrado
- ✅ Compara valores planejados vs. reais

**Teste 4: Atualizar exercício (série, rep, carga)**
- ✅ Adicionar exercício 1
- ✅ POST com mesmo exercise_id mas dados novos
- ✅ Retorna 200 (atualizado, não criado duplicado)

**Teste 5: Finalizar sessão com sucesso**
- ✅ Criar sessão + adicionar exercícios
- ✅ PUT /sessions/{id} com status="completed"
- ✅ Retorna 200, sessão marcada como completed
- ✅ Campo `completed_at` preenchido

**Teste 6: Não pode finalizar sessão sem exercícios**
- ✅ Criar sessão vazia
- ✅ PUT com status="completed"
- ✅ Retorna 422 "Adicione pelo menos 1 exercício"

**Teste 7: Listar sessões com paginação**
- ✅ Criar 15 sessões
- ✅ GET /sessions?page=1&limit=10
- ✅ Retorna 10 itens + total=15
- ✅ Ordenação por data (mais recentes primeiro)

**Teste 8: Filtrar sessões por período**
- ✅ GET /sessions?start_date=2026-04-01&end_date=2026-04-15
- ✅ Retorna apenas sessões nesse período

**Teste 9: Buscar sessão específica com exercícios**
- ✅ GET /sessions/{id}
- ✅ Retorna 200 com todos os exercícios
- ✅ Inclui planned vs. actual

**Teste 10: Visualizar calendário do mês**
- ✅ GET /calendar?year=2026&month=4
- ✅ Retorna dias com status (completed, skipped, no_plan)
- ✅ Summary com totais

**Teste 11: Progressão de exercício (evolução de carga)**
- ✅ Criar 3 sessões com mesmo exercício, carga crescente
- ✅ GET /progression/{exercise_id}
- ✅ Retorna data_points ordenados
- ✅ Calcula trend (increasing, decreasing, stable)

**Teste 12: Controle de acesso - Aluno vs. Personal**
- ✅ Aluno cria sessão própria
- ✅ Personal consegue ler (GET)
- ✅ Personal NÃO consegue editar (PUT) - retorna 403
- ✅ Personal NÃO consegue deletar - retorna 403

**Teste 13: Deletar sessão (soft delete)**
- ✅ Criar e completar sessão
- ✅ DELETE /sessions/{id}
- ✅ Retorna 204
- ✅ GET /sessions/{id} retorna 404 (ou marcar com status="deleted")
- ✅ Sessão ainda existe no BD mas marcada como deletada

**Teste 14: Validação de dados**
- ✅ Enviar série=0 → erro 422
- ✅ Enviar carga negativa → erro 422
- ✅ Enviar mood inválido → erro 422
- ✅ Enviar session_date futura → erro 422

**Teste 15: Dor/Incômodo**
- ✅ Enviar pain_or_discomfort=true sem description
- ✅ Retorna erro 422
- ✅ Enviar com description → sucesso

**Teste 16: Múltiplos exercícios em uma sessão**
- ✅ Adicionar 5 exercícios diferentes
- ✅ GET /sessions/{id}
- ✅ Retorna todos os 5 com dados completos

**Teste 17: Series details (opcional)**
- ✅ Adicionar exercício com series_details detalhado
- ✅ Validar que poder editar série por série depois (futuro)

### 5.2 Testes Unitários

**test_logbook_dto.py:**
- ✅ CreateSessionDTO com dados válidos
- ✅ SessionExerciseDTO com dados válidos
- ✅ Rejeita série/rep/carga negativas
- ✅ Validação de mood enum
- ✅ Validação de datas

**test_logbook_service.py:**
- ✅ Calcular volume (séries × reps × carga)
- ✅ Detectar progressão (carga anterior vs. atual)
- ✅ Gerar página do calendário
- ✅ Validar acesso por role

**test_logbook_repository.py:**
- ✅ CRUD de sessão
- ✅ Query de exercícios por sessão
- ✅ Query de exercícios por usuário + período
- ✅ Índices de performance (user_id, session_date)

---

## 📋 6. Critérios de Aceitação

### User Story 1: Aluno Registra Treino Completado
```
DADO que o aluno tem ficha de treino ativa
QUANDO ele começa POST /sessions
E adiciona exercícios com valores reais (séries, reps, carga)
E finaliza PUT /sessions/{id} com status="completed"
ENTÃO a sessão é armazenada com data/hora
E pode visualizar depois em GET /sessions/{id}
```

### User Story 2: Visualizar Evolução de Carga
```
DADO que aluno tem 3+ sessões com mesmo exercício
QUANDO acessa GET /progression/{exercise_id}
ENTÃO vê gráfico/dados mostrando carga ao longo do tempo
E identifica se está evoluindo (aumentando) vs. estagnado
```

### User Story 3: Calendario de Treinos
```
DADO que aluno tem histórico de treinos
QUANDO acessa GET /calendar?month=4&year=2026
ENTÃO vê calendário com dias:
  - ✅ Completed (treinou)
  - ❌ Skipped (deveria treinar mas não fez)
  - ◇ No plan (dia sem ficha atribuída)
```

### User Story 4: Personal Acompanha Logbook
```
DADO que personal tem alunos
QUANDO acessa GET /sessions?user_id={aluno_id}
ENTÃO vê histórico de treinos do aluno
E visualiza carga, reps, notas, dor/incômodo
E NÃO consegue editar (apenas ler)
```

### User Story 5: Notas Personalizadas
```
DADO que aluno registra exercício
QUANDO adiciona exercise_notes ou general_notes
ENTÃO são armazenadas para consulta futura
E podem ter detalhes de dor, modificação, dificuldade
```

---

## 📁 7. Arquivos a Criar

```
backend/
├── app/
│   ├── models/
│   │   └── logbook.py              # Models: WorkoutSession, SessionExercise
│   ├── dtos/
│   │   └── logbook_dto.py          # DTOs para logbook
│   ├── services/
│   │   └── logbook_service.py      # Lógica de negócio
│   ├── repositories/
│   │   └── logbook_repository.py   # Acesso ao banco
│   ├── controllers/
│   │   └── logbook_controller.py   # Orquestração
│   └── routes/
│       └── logbook.py              # 8 endpoints
│
├── tests/
│   ├── test_logbook_sessions.py    # Integração (17 testes)
│   └── unit/
│       ├── test_logbook_dto.py
│       ├── test_logbook_service.py
│       └── test_logbook_repository.py
│
└── main.py                          # Registrar rotas
```

---

## ⚡ 8. Ordem de Implementação

### Fase 1: Estrutura Base (1-2h)
```
1. Criar app/models/logbook.py
2. Criar app/dtos/logbook_dto.py
3. Rodar migrations (alembic)
```

### Fase 2: Lógica de Negócio (1-2h)
```
4. Criar app/repositories/logbook_repository.py
5. Criar app/services/logbook_service.py
```

### Fase 3: API (1-2h)
```
6. Criar app/controllers/logbook_controller.py
7. Criar app/routes/logbook.py (8 endpoints)
8. Registrar em main.py
```

### Fase 4: Testes (2-3h)
```
9. Criar tests/test_logbook_sessions.py (17 testes)
10. Criar tests/unit/* (unitários)
11. Validar cobertura > 80%
```

---

## 🎯 9. Definição de Pronto ("Done")

Logbook está **pronto** quando:

- ✅ Todos os 8 endpoints funcionam (`POST sessions`, `POST sessions/{id}/exercises`, `PUT sessions/{id}`, `GET sessions`, `GET sessions/{id}`, `GET calendar`, `GET progression/{id}`, `DELETE sessions/{id}`)
- ✅ Aluno pode criar sessão vinculada a ficha ativa
- ✅ Aluno pode registrar exercícios com séries, reps, carga reais
- ✅ Aluno pode adicionar notas e registrar dor/incômodo
- ✅ Aluno pode finalizar sessão com status="completed"
- ✅ Calendário mostra dias completados vs. faltados
- ✅ Evolução de carga calculada e exibida com trend
- ✅ Personal pode visualizar (read-only) logbook de seus alunos
- ✅ Controle de acesso por role (aluno vs. personal vs. admin)
- ✅ Soft delete implementado (não hard delete)
- ✅ Testes de integração: **17+ testes passando**
- ✅ Testes unitários: **5+ testes passando**
- ✅ Cobertura de testes: **≥ 80%**
- ✅ Documentação automática no Swagger (`/docs`)
- ✅ Performance: queries otimizadas com índices (user_id, session_date)
- ✅ Auditoria: tudo rastreável (created_at, updated_at)

---

## 📊 10. Requisitos Mapeados do PDF

| Requisito | ID | Status |
|-----------|-----|--------|
| Aluno registrar pesos, séries, repetições efetivamente executadas | RF-15 | ✅ Este PRD |
| Logbook vinculado à ficha de treino ativa, pré-populando exercícios | RF-16 | ✅ Integração com ficha |
| Sistema calcular e exibir evolução de carga ao longo do tempo | RF-17 | ✅ GET /progression |
| Aluno adicionar notas livres a cada sessão | RF-18 | ✅ exercise_notes + general_notes |
| Personal ter acesso de leitura ao logbook de seus alunos | RF-19 | ✅ Controle acesso |
| Logbook exibir calendário com dias realizados e não realizados | RF-20 | ✅ GET /calendar |

---

## 💼 11. Regras de Negócio Aplicáveis

| Regra | Implementação |
|-------|--------------|
| RN-01: Um aluno só pode ter uma ficha ativa por vez | Validar ao criar sessão |
| RN-02: Só Personal/Professor/Gestor podem criar fichas | Mas aluno registra sessão |
| RN-03: Validação de treino com base em logbook | Aqui registramos, análise em outro PRD |
| RN-08: Logbook é visível apenas para aluno e seus personal(is) | Validar acesso |

---

## ⚙️ 12. Índices e Performance

### Índices Recomendados
```sql
CREATE INDEX idx_workout_sessions_user_id ON workout_sessions(user_id);
CREATE INDEX idx_workout_sessions_date ON workout_sessions(session_date);
CREATE INDEX idx_workout_sessions_user_date ON workout_sessions(user_id, session_date);
CREATE INDEX idx_session_exercises_session_id ON session_exercises(session_id);
CREATE INDEX idx_session_exercises_exercise_id ON session_exercises(exercise_id);
```

### Queries Críticas
- Listar sessões de um aluno (paginado): `user_id` index critical
- Calendário mensal: `user_id` + `session_date` between
- Progressão de exercício: `user_id` + `exercise_id` + `session_date`

---

## 📚 13. Integração com Outros PRDs

### Depende De:
- **PRD_USUARIOS.md** → User model, authenticação, roles
- **PRD_FICHA_TREINO.md** → Ficha ativa, Exercise model

### Base Para:
- **PRD_ANALISA_IA.md** → Dados históricos de logbook para análise
- **PRD_METAS.md** → Progresso baseado em logbook
- **PRD_NOTIFICACOES.md** → Alertar Personal se aluno não registra
- **PRD_DASHBOARD_PROFISSIONAL.md** → Visualizar logbook consolidado

---

## 📝 Notas Finais

### Decisões Arquiteturais

| Decisão | Razão |
|---------|------|
| Soft delete, não hard delete | Auditoria + LGPD compliance |
| Personal read-only, não edit | Integridade de dados + confiança |
| Séries detalhadas (JSON) | Flexibilidade futura (série por série) |
| Mood/difficulty fields | Contexto para análise IA depois |

### Futuras Extensões
- **MVP 2:** Editor de série-por-série (foto/vídeo validação)
- **MVP 3:** Análise IA em cima do logbook
- **MVP 4:** Wearable integration (Apple Watch, Garmin)
- **MVP 5:** Sincronização offline-first

---

*Criado para: OmniConnect Fitness - Alpha EdTech*  
*Arquitetura: FastAPI + SQLAlchemy + PostgreSQL*  
*Responsável: Equipe Backend*  
*Data: 2026-04-21*
