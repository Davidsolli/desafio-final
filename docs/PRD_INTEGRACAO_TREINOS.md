# PRD: Integração do Módulo de Fichas de Treino - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-05-01  
**Status:** 📋 Pronto para Implementação  
**Responsável:** Gemini (AI Agent)

---

## 📋 1. Visão Geral

### Objetivo
Sincronizar a lógica de negócio do backend (FastAPI) com a interface mobile (Flutter), garantindo que o Personal possa gerenciar treinos e o Aluno possa visualizá-los em tempo real, utilizando o catálogo de exercícios existente.

### Contexto Técnico
- **Backend:** FastAPI com arquitetura em camadas (Controller -> Service -> Repository).
- **Frontend:** Flutter com widgets modulares (Dashboard, Sheets, Details).
- **Dados:** Integração baseada em DTOs Pydantic (Back) e Modelos Dart (Front).

---

## 🔌 2. Endpoints e Contratos de Dados

### 2.1 Mapeamento de Endpoints (Backend -> Frontend)
O frontend deve consumir os seguintes endpoints definidos em `workout_sheet_controller.py`:

| Funcionalidade | Método | Rota | Componente Flutter |
| :--- | :--- | :--- | :--- |
| **Listar Fichas** | `GET` | `/api/v1/workout-sheets` | `TrainerSheets` |
| **Criar Ficha** | `POST` | `/api/v1/workout-sheets` | Botão "Nova" em `TrainerSheets` |
| **Ver Detalhes** | `GET` | `/api/v1/workout-sheets/{id}` | `TrainerStudentDetail` |
| **Duplicar Ficha** | `POST` | `/api/v1/workout-sheets/{id}/duplicate` | Action em `TrainerSheets` |
| **Buscar Catálogo**| `GET` | `/api/v1/exercise-catalog` | Modal de Busca de Exercícios |

### 2.2 Sincronização de DTOs
O frontend **deve** espelhar exatamente os tipos do `workout_sheet_dto.py`:
- `day_of_week`: Inteiro (0=Segunda, 6=Domingo).
- `load_kg`: Float (Carga).
- `rest_seconds`: Inteiro (Descanso).
- `muscle_group`: String (Validada contra `VALID_MUSCLE_GROUPS`).

---

## 💼 3. Regras de Negócio de Integração (RNs)

1. **RN-01 (Unicidade Diária):** O frontend deve tratar o erro 400 caso o Personal tente criar uma segunda ficha ativa para o mesmo dia da semana para um aluno.
2. **RN-02 (Controle de Acesso):** O botão de edição/criação deve ser habilitado apenas para roles `admin`, `personal_trainer`, `professor` ou `gestor`.
3. **RN-03 (Ordenação):** A lista de exercícios deve ser exibida respeitando o campo `order` retornado pela API.

---

## 🚀 4. Workflow de Implementação (IA)

Para implementar esta task via LLM, utilize o prompt abaixo conforme o `IA_WORKFLOW.md`:

**Prompt para a LLM:**
> "Claude, implemente a integração do frontend Flutter com o backend FastAPI para o módulo de treinos.
> 
> **Contexto:**
> - Backend: `WorkoutSheetController` pronto.
> - Frontend: Widgets `TrainerSheets` e `TrainerStudentDetail` usando mock.
> 
> **Tarefas:**
> 1. Criar `workout_sheet_model.dart` baseado nos DTOs Python fornecidos.
> 2. Criar `workout_sheet_service.dart` no Flutter usando o pacote de rede do projeto.
> 3. Substituir dados estáticos de `mock_data.dart` pelas chamadas assíncronas da API.
> 4. Seguir `BRANCH_STRATEGY.md`: Criar branch `feat/treinos-integracao`.
> 5. Seguir `COMMIT_GUIDE.md`: Usar conventional commits em português."

---

## 🎯 5. Definição de Pronto (DoD)

- [ ] Modelos Dart criados e testados.
- [ ] Service Flutter realizando chamadas aos 6 endpoints do controller.
- [ ] UI de listagem e detalhes carregando dados reais.
- [ ] Cobertura de testes de integração no frontend ≥ 80%.
- [ ] Pull Request criado contra a branch `develop`.

---
*OmniConnect Fitness - Documentação Técnica Interna*
