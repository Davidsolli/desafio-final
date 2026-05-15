# PRD: Montagem e Diário de Dieta (Logbook Alimentar) - OmniConnect Fitness

**Versão:** 1.1  
**Data:** 2026-05-03  
**Status:** 📋 Em Especificação  
**Responsável:** José Henrique

---

## 📋 1. Visão Geral

### Objetivo
Criar um sistema de gerenciamento, montagem de dietas e acompanhamento diário (Logbook Alimentar) para o aplicativo, utilizando os dados da Tabela Brasileira de Composição de Alimentos (TACO) como base oficial, gratuita e nativa (PT-BR).

### Por Quê?
O OmniConnect precisa de um módulo nutricional integrado aos treinos e ao acompanhamento do aluno. O uso da tabela TACO hospedada no próprio banco de dados garante custo zero e performance. Além disso, a adição de um Diário Alimentar (estilo MyFitnessPal) agrega valor imenso ao Dashboard do Profissional, permitindo que a Inteligência Artificial e o Personal avaliem a adesão real do aluno ao plano prescrito.

### Escopo
✅ **Incluído neste PRD:**
- Tabela `FoodCatalog` semeada via script (JSON da Tabela TACO) como base global intocável.
- Criação de **Alimentos Personalizados** (`CustomFood`) por alunos e personais (base de dados isolada para não sujar a TACO global).
- Criar dieta atribuída a um aluno (com cálculo automático de macros totais).
- **Dietas Múltiplas:** O personal pode criar a "Dieta Prescrita", e o aluno pode criar sua própria "Dieta Personalizada" paralela, sem que uma altere a outra.
- Estruturação da dieta em refeições (`DietMeal`) e itens (`DietItem`).
- Diário Alimentar (`DietLogbook` e `DietLogbookEntry`) onde o aluno registra o que comeu.
- Busca de alimentos unificada (Catálogo TACO + Alimentos Personalizados do usuário).
- Integração com Notificações (agendamento baseado no horário das refeições).
- Visibilidade para a IA (RAG) gerar análises.

❌ **NÃO incluído (futuro PRD):**
- Integração de produtos industrializados por código de barras (Open Food Facts).
- Geração automática de dietas completas por IA.
- Contador de água.

---

## 📊 2. Especificação Técnica

### 2.1 Modelo de Dados (Prescrição)

#### Tabela: FoodCatalog (Catálogo Base - TACO)
```python
class FoodCatalog(Base):
    """Catálogo de alimentos baseados na TACO (somente leitura)"""
    __tablename__ = "food_catalog"
    
    id: str                       # ID original da TACO (ex: "1")
    name: str                     # Nome do alimento (ex: "Arroz, tipo 1, cozido")
    category: str                 # Categoria (Cereais, Carnes, Frutas)
    energy_kcal: float            # Calorias em 100g
    protein_g: float              # Proteínas em 100g
    carbohydrate_g: float         # Carboidratos em 100g
    lipid_g: float                # Gorduras totais em 100g
    fiber_g: float                # Fibras em 100g
```

#### Tabela: CustomFood (Alimentos Personalizados do Usuário)
```python
class CustomFood(Base):
    """Alimentos criados por alunos ou personais fora da base TACO"""
    __tablename__ = "custom_foods"
    
    id: UUID
    user_id: UUID                 # Quem criou (só essa pessoa e seu personal veem)
    name: str                     # Ex: "Whey Protein Max Titanium"
    category: str                 # Ex: "Suplementos"
    energy_kcal: float            # Calorias em 100g (ou porção base)
    protein_g: float              # Proteínas em 100g
    carbohydrate_g: float         # Carboidratos em 100g
    lipid_g: float                # Gorduras totais em 100g
    fiber_g: float                # Fibras em 100g
    created_at: datetime
```

#### Tabela: Diet (Dieta do Aluno)
```python
class Diet(Base):
    """Dieta atribuída a um aluno"""
    __tablename__ = "diets"
    
    id: UUID
    user_id: UUID                 # Aluno dono da dieta (FK users)
    professional_id: UUID         # Personal que prescreveu (Null se for dieta criada pelo próprio aluno)
    is_custom: bool               # True se criada pelo próprio aluno, False se for do personal
    name: str                     # Nome da dieta (ex: "Dieta Hipertrofia")
    goal: str                     # Objetivo (bulking, cutting, maintenance)
    is_active: bool               # Apenas uma dieta deve estar ativa
    created_at: datetime
    updated_at: datetime
    meals: List[DietMeal]         # Relação 1:N
```

#### Tabela: DietMeal e DietItem
```python
class DietMeal(Base):
    """Refeição de uma dieta prescrita"""
    __tablename__ = "diet_meals"
    id: UUID
    diet_id: UUID
    name: str                     # Ex: "Café da Manhã"
    time: str                     # Horário sugerido (ex: "08:00") - Usado para Notificações
    order: int                    # Ordem no dia (1, 2, 3)
    items: List[DietItem]

class DietItem(Base):
    """Alimento específico dentro da refeição prescrita"""
    __tablename__ = "diet_items"
    id: UUID
    meal_id: UUID
    food_id: str                  # FK food_catalog (Taco) - Pode ser Null
    custom_food_id: UUID          # FK custom_foods (Personalizado) - Pode ser Null
    # Pelo menos UM dos IDs de food deve estar preenchido
    quantity_g: float             # Quantidade recomendada em gramas
    observations: str
```

### 2.2 Modelo de Dados (Diário Alimentar do Aluno)

#### Tabela: DietLogbook (Registro Diário)
```python
class DietLogbook(Base):
    """Resumo do dia alimentar do aluno"""
    __tablename__ = "diet_logbooks"
    
    id: UUID
    user_id: UUID                 # FK users
    date: date                    # Data do diário (ex: 2026-05-03)
    total_kcal: float             # Somatório calculado das calorias consumidas no dia
    total_protein: float          # Somatório de proteínas
    total_carbs: float            # Somatório de carboidratos
    total_fats: float             # Somatório de gorduras
    created_at: datetime
    entries: List[DietLogbookEntry] # Relação 1:N
```

#### Tabela: DietLogbookEntry (Item consumido)
```python
class DietLogbookEntry(Base):
    """Item efetivamente consumido pelo aluno no dia"""
    __tablename__ = "diet_logbook_entries"
    
    id: UUID
    logbook_id: UUID              # FK diet_logbooks
    meal_name: str                # Referência de qual refeição foi (ex: "Café da Manhã")
    food_id: str                  # FK food_catalog (Tabela TACO) - Pode ser Null
    custom_food_id: UUID          # FK custom_foods - Pode ser Null
    quantity_g: float             # Quantidade efetivamente consumida
    # Os macros do alimento ingerido são gravados no momento da inserção (Snapshot)
    kcal: float
    protein: float
    carbs: float
    fats: float
```

---

## 🔌 3. Endpoints HTTP

### 3.1 Catálogo, Alimentos Personalizados e Prescrição
*   **`GET /api/v1/food-catalog`**: Busca unificada de alimentos (Pesquisa na TACO + `CustomFood` criados pelo usuário atual). Retorna um único array consolidado.
*   **`POST /api/v1/custom-foods`**: Cria um novo alimento personalizado (`CustomFood`) na conta do usuário (aluno ou personal).
*   **`POST /api/v1/diets`**: Cria dieta. 
    * Se for chamado por Personal: Cria dieta com `is_custom=False` (Dieta Prescrita). Desativa a dieta prescrita anterior.
    * Se for chamado por Aluno: Cria dieta com `is_custom=True` (Dieta Personalizada). Desativa a dieta customizada anterior, mas **mantém a do personal intacta**.
*   **`GET /api/v1/diets/{id}`**: Busca a dieta detalhada. **Importante**: O DTO de resposta DEVE calcular matematicamente a soma total de `kcal`, `protein`, `carbs` e `fats` de todos os itens prescritos. Isso será usado pelo app para comparar com a TMB e Gasto Calórico (RF-36).
*   **`PUT /api/v1/diets/{id}`** e **`DELETE /api/v1/diets/{id}`**: Editar e Soft Delete.
*   **`POST /api/v1/diets/{id}/duplicate`**: Duplicar dieta para outro aluno ou facilitar edição.

### 3.2 Diário Alimentar (Logbook)
*   **`POST /api/v1/diet-logbook`**: Adiciona um item consumido (`DietLogbookEntry`) no dia atual ou especificado. O Service buscará na tabela TACO e calculará os macros baseados nas gramas consumidas, somando automaticamente ao `DietLogbook` daquele dia.
*   **`GET /api/v1/diet-logbook/{date}`**: Retorna o diário completo do aluno em uma data específica.
*   **`DELETE /api/v1/diet-logbook/entries/{entry_id}`**: Remove um alimento inserido por engano e atualiza os totais.

---

## 🔐 4. Requisitos de Segurança & Regras de Negócio

1.  **Criação de Alimentos (`CustomFood`):** Alunos e Profissionais podem criar. Os alimentos criados por alunos só são visíveis para si próprios e seus personais. Alimentos criados por personais ficam disponíveis para ele e seus alunos.
2.  **Criação de Dietas (Tipos Isolados):** 
    * A role `personal_trainer` gerencia a "Dieta Prescrita" do aluno (`is_custom=False`).
    * O `aluno` gerencia apenas a sua "Dieta Personalizada" paralela (`is_custom=True`).
    * A RN-01 se divide: O aluno pode ter **no máximo uma Dieta Prescrita ativa** e **no máximo uma Dieta Customizada ativa** por vez.
3.  **Visualização:** O Aluno vê ambas as dietas.
4.  **Diário Alimentar:** Apenas o Aluno pode registrar o que comeu. O Personal possui permissão de leitura sobre o logbook de seus alunos.

---

## ⚙️ 5. Integrações Arquiteturais

1.  **Integração com Notificações (RF-38):**
    Quando uma dieta for marcada como `is_active = True`, o backend deve notificar o serviço de push (Firebase FCM) para agendar lembretes para o aluno com base no campo `time` de cada `DietMeal` (ex: Lembrete "Hora do Almoço" às 12:30).
2.  **Integração com Inteligência Artificial (RF-26):**
    O conteúdo da Dieta Ativa e os registros diários do Logbook Alimentar devem estar disponíveis como contexto para o pipeline de RAG (Retrieval-Augmented Generation). O LLM usará esses dados para analisar a adesão do aluno e a compatibilidade do plano com suas metas.
3.  **Integração com Cálculo Corporal (RF-36):**
    O cálculo automático de macros totais na API `GET /diets/{id}` servirá para o Frontend plotar o gráfico comparativo entre Dieta Prescrita *vs* TMB / Gasto Calórico Diário.

---

## 🧪 6. Testes Automatizados
-   **Unitários:** Testar funções matemáticas de soma de macros no Service (`test_diet_service.py`), garantindo que 150g de Arroz na TACO gere as kcal/macros exatos proporcionais.
-   **Integração:** `test_diets.py` e `test_diet_logbook.py` garantindo isolamento de usuário (Aluno A não pode ver o logbook do Aluno B) e permissões de escrita (Aluno não prescreve dieta).

---

## 📁 7. Estrutura de Arquivos

```text
backend/
├── app/
│   ├── models/
│   │   ├── diet.py                 # Diet, DietMeal, DietItem
│   │   ├── diet_logbook.py         # DietLogbook, DietLogbookEntry
│   │   └── food_catalog.py         # FoodCatalog
│   ├── dtos/
│   │   ├── diet_dto.py
│   │   └── diet_logbook_dto.py
│   ├── services/
│   │   ├── diet_service.py
│   │   └── diet_logbook_service.py
│   ├── repositories/diet_repository.py
│   ├── controllers/diet_controller.py
│   └── routes/
│       ├── diet.py
│       ├── diet_logbook.py
│       └── food_catalog.py
├── scripts/
│   └── seed_food.py                # Script para popular TACO
└── tests/
    ├── test_diets.py
    └── test_diet_logbook.py
```

---

*Criado para: OmniConnect Fitness - Alpha EdTech*  
*Baseado nos Requisitos Oficiais de Sistemas Integrados (v1.1)*
