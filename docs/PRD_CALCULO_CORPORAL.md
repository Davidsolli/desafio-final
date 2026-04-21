# PRD: Cálculo de Composição Corporal - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-04-21  
**Status:** 📋 Em Especificação  
**Responsável:** David Oliveira

---

## 📋 1. Visão Geral

### Objetivo
Criar sistema de cálculo de métricas corporais:
- ✅ Calcular IMC (Índice de Massa Corporal)
- ✅ Calcular TMB (Taxa Metabólica Basal) - Harris-Benedict/Mifflin-St Jeor
- ✅ Registro periódico de medidas corporais (circunferências, % gordura)
- ✅ Gráficos de evolução de peso e medidas
- ✅ Calcular gasto calórico diário estimado

### Por Quê?
- Métricas corporais motivam + rastreiam resultado
- IMC e TMB são base para recomendações nutricionais
- Gráficos mostram evolução visual

### Escopo
✅ **Incluído:**
- IMC, TMB, gasto calórico
- Registro de medidas (circunferências, % gordura)
- Histórico e gráficos

❌ **NÃO incluído:**
- Cálculo de marcos/pontos corporais
- Análise de composição avançada

---

## 📊 2. Especificação Técnica

### 2.1 Modelo de Dados

#### Tabela: BodyMeasurement (Medida Corporal)
```python
class BodyMeasurement(Base):
    """Registro de medidas corporais"""
    
    __tablename__ = "body_measurements"
    
    id: UUID
    user_id: UUID                 # Aluno (FK Users)
    
    # Biometria principal
    weight_kg: float              # Peso em kg
    height_cm: float              # Altura em cm (imutável)
    
    # Circunferências (cm)
    chest_cm: float               # Peito (opcional)
    waist_cm: float               # Cintura (opcional)
    hip_cm: float                 # Quadril (opcional)
    thigh_cm: float               # Coxa (opcional)
    arm_cm: float                 # Braço (opcional)
    
    # Composição corporal
    body_fat_percentage: float    # % gordura (opcional, pode vir de bioimpedância)
    
    # Calculados
    bmi: float                    # IMC = peso / (altura²)
    bmr_kcal: float               # TMB em kcal
    tdee_kcal: float              # Gasto diário (TMB × fator atividade)
    
    # Contexto
    activity_level: str           # "sedentary", "light", "moderate", "active", "very_active"
    measured_at: datetime         # Quando foi medido
    notes: str                    # Observações
    
    created_at: datetime
    updated_at: datetime
```

---

### 2.2 DTOs

#### CreateMeasurementDTO
```json
{
  "weight_kg": 85.5,
  "chest_cm": 98,
  "waist_cm": 82,
  "hip_cm": 95,
  "body_fat_percentage": 18.5,
  "activity_level": "moderate",
  "notes": "Medido pela manhã",
  "measured_at": "2026-04-21T08:00:00Z"
}
```

#### MeasurementResponseDTO
```json
{
  "id": "550e8400...",
  "user_id": "550e8400...",
  "weight_kg": 85.5,
  "height_cm": 175,
  "bmi": 27.9,
  "bmr_kcal": 1850,
  "tdee_kcal": 2775,
  "body_fat_percentage": 18.5,
  "measured_at": "2026-04-21T08:00:00Z"
}
```

---

## 🔌 3. Endpoints HTTP

### 3.1 POST /api/v1/measurements (Registrar Medida)

**Request:**
```http
POST /api/v1/measurements HTTP/1.1
Authorization: Bearer {token}

{
  "weight_kg": 85.5,
  "chest_cm": 98,
  "body_fat_percentage": 18.5,
  "activity_level": "moderate"
}
```

**Response 201:**
```json
{
  "id": "550e8400...",
  "bmi": 27.9,
  "bmr_kcal": 1850,
  "tdee_kcal": 2775
}
```

---

### 3.2 GET /api/v1/measurements (Listar Medidas)

**Request:**
```http
GET /api/v1/measurements?user_id=550e8400...&limit=10 HTTP/1.1
Authorization: Bearer {token}
```

**Response 200:**
```json
{
  "total": 12,
  "data": [
    {
      "id": "550e8400...",
      "weight_kg": 85.5,
      "bmi": 27.9,
      "measured_at": "2026-04-21T08:00:00Z"
    }
  ]
}
```

---

### 3.3 GET /api/v1/measurements/latest (Última Medida)

**Response 200:**
```json
{
  "id": "550e8400...",
  "weight_kg": 85.5,
  "bmi": 27.9,
  "bmr_kcal": 1850,
  "tdee_kcal": 2775
}
```

---

### 3.4 GET /api/v1/measurements/evolution (Evolução)

**Request:**
```http
GET /api/v1/measurements/evolution?metric=weight&days=90 HTTP/1.1
Authorization: Bearer {token}
```

**Response 200:**
```json
{
  "metric": "weight",
  "data": [
    { "date": "2026-01-21", "value": 88.0 },
    { "date": "2026-02-21", "value": 86.5 },
    { "date": "2026-03-21", "value": 85.5 },
    { "date": "2026-04-21", "value": 84.0 }
  ],
  "statistics": {
    "current": 84.0,
    "initial": 88.0,
    "change": -4.0,
    "change_percentage": -4.55
  }
}
```

---

## 🧮 4. Fórmulas

### IMC (Índice de Massa Corporal)
```
IMC = peso(kg) / altura(m)²

Categorias:
- < 18.5: Abaixo do peso
- 18.5-24.9: Peso normal
- 25-29.9: Sobrepeso
- 30-34.9: Obesidade grau 1
- ≥ 35: Obesidade grau 2+
```

### TMB - Fórmula Mifflin-St Jeor (Padrão)
```
Homem: TMB = (10 × peso) + (6.25 × altura) - (5 × idade) + 5
Mulher: TMB = (10 × peso) + (6.25 × altura) - (5 × idade) - 161

Usa `gender` do perfil do usuário
```

### TDEE (Total Daily Energy Expenditure)
```
TDEE = TMB × Fator de Atividade

Fatores:
- Sedentário (pouco/sem exercício): × 1.2
- Leve (1-3 dias/sem): × 1.375
- Moderado (3-5 dias/sem): × 1.55
- Ativo (6-7 dias/sem): × 1.725
- Muito Ativo (2x/dia): × 1.9
```

---

## 🔐 5. Segurança

- ✅ Aluno vê apenas SUAS medidas
- ✅ Personal vê medidas dos seus alunos
- ✅ Admin vê todas
- ✅ Altura é imutável (validar se tenta alterar)

---

## 🧪 6. Testes (6+ testes)

**Teste 1:** Criar medida com sucesso  
**Teste 2:** Calcular IMC corretamente  
**Teste 3:** Calcular TMB (homem e mulher)  
**Teste 4:** Calcular TDEE por activity level  
**Teste 5:** Listar histórico ordenado  
**Teste 6:** Evolução com estatísticas  

---

## 🎯 Definição de Pronto

- ✅ 4 endpoints
- ✅ IMC, TMB, TDEE calculados
- ✅ Histórico com evolução
- ✅ 6+ testes
- ✅ Cobertura ≥80%

---

## ⚡ Tempo Estimado: 8 horas

- Models + DTOs: 2h
- Fórmulas + Service: 2h
- Endpoints: 2h
- Testes: 2h

---

*PRD para OmniConnect Fitness - Data: 21 Abril 2026*
