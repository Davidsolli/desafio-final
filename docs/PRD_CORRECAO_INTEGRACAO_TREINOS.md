# PRD: Correção da Integração do Módulo de Treinos (Aluno) - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-05-05  
**Status:** 📋 Pronto para Implementação  
**Responsável:** Anderson Chaves  
**Branch Sugerida:** `fix/treinos-integracao-aluno`

---

## 📋 1. Visão Geral

### Problema Identificado

A análise do módulo de treinos revelou que a integração backend-frontend está **incompleta no lado do Aluno**. Enquanto a camada do Personal Trainer (criar, editar, duplicar, deletar fichas) já consome a API real, a tela do Aluno (`workouts_screen.dart`) e o fluxo de seleção de aluno no dialog de criação ainda usam **dados estáticos de `mock_data.dart`**, tornando impossível que o aluno veja fichas criadas pelo personal no banco de dados real.

### Contexto Técnico

- **Backend:** FastAPI completamente implementado com 7 endpoints RESTful.
- **DTOs Dart:** `workout_sheet_model.dart` espelha exatamente os DTOs Python.
- **Service Flutter:** `workout_sheet_service.dart` e `workout_sheet_provider.dart` já existem e funcionam.
- **Problema:** `workouts_screen.dart` ignora a infraestrutura pronta e usa `mock_data.dart`.

---

## 🔍 2. Diagnóstico de Bugs

### BUG-01 — `workouts_screen.dart`: Fichas do Aluno Totalmente Mockadas

**Localização:** `frontend/lib/screens/student/workouts_screen.dart`

**Sintoma:** A tela exibe `workouts` importados de `mock_data.dart` (constante hardcoded com 3 treinos fictícios: "Treino A", "Treino B", "Treino C") em vez de consultar a API real.

**Impacto:** Fichas criadas pelo Personal Trainer no backend **não aparecem para o Aluno**. A funcionalidade principal do módulo está quebrada para o usuário final.

**Causa Raiz:** A `WorkoutSheetProvider` e `WorkoutSheetService` já existem e funcionam, mas não foram conectadas nesta tela. O widget usa a classe `Workout` de `mock_data.dart` (modelo primitivo com campos simples: id, name, label, exercises) em vez do `WorkoutSheetResponse` do modelo real.

**Modelo Atual (mock):**
```dart
// mock_data.dart - modelo simples sem relação com API
class Exercise { String id, name, muscle, sets, reps, load, rest; }
class Workout { String id, name, label; List<Exercise> exercises; }
const workouts = [Workout('a', 'Treino A', 'Peito + Tríceps', [...]), ...];
```

**Modelo Real (API):**
```dart
// workout_sheet_model.dart - espelha backend
class WorkoutSheetListItem { UUID id, userId; String name; int dayOfWeek; int exerciseCount; }
class WorkoutSheetResponse { ... List<ExerciseResponse> exercises; }
```

---

### BUG-02 — `workouts_screen.dart`: Tela de Execução Usa Mock Irrecuperável

**Localização:** `frontend/lib/screens/student/workouts_screen.dart`

**Sintoma:** Ao tocar em uma ficha, a tela de detalhe/execução exibe campos do modelo `Mock.Exercise` (sets, reps como String, campo `muscle`). O backend retorna `ExerciseResponse` com campos totalmente diferentes (series, repetitions, loadKg, restSeconds, muscle_group, order).

**Impacto:** Mesmo que a lista fosse conectada, a tela de execução de treino travaria ou exibiria dados incorretos por incompatibilidade de tipos.

**Mapeamento de Incompatibilidades:**

| Campo Mock | Campo API Real | Tipo Mock | Tipo Real |
|------------|---------------|-----------|-----------|
| `exercise.sets` | `exercise.series` | `String` | `int` |
| `exercise.reps` | `exercise.repetitions` | `String` | `int` |
| `exercise.load` | `exercise.loadKg` | `String` | `double` |
| `exercise.rest` | `exercise.restSeconds` | `String` | `int` |
| `exercise.muscle` | `exercise.muscleGroup` | `String` | `String (whitelist)` |
| *(ausente)* | `exercise.order` | — | `int` |
| *(ausente)* | `exercise.gifUrl` | — | `String?` |
| *(ausente)* | `exercise.observations` | — | `String?` |

---

### BUG-03 — `trainer_student_detail.dart`: Botão "+ Novo Treino" Sem Ação

**Localização:** `frontend/lib/screens/trainer/trainer_student_detail.dart` — Tab "Treinos"

**Sintoma:** O botão `+ Novo` existe na tab de Treinos do detalhe do aluno, mas não abre nenhum dialog ou navega para criação de ficha. Ao ser pressionado provavelmente não faz nada ou é um `TODO` sem ação.

**Impacto:** O Personal Trainer não consegue criar uma ficha diretamente na tela do aluno. Precisa ir para a tela `TrainerSheets` e criar lá — mas o `user_id` passado precisa ser o do aluno correto.

**Comportamento Esperado:** Ao clicar "+ Novo" na tab Treinos de um aluno específico, deve abrir o `CreateWorkoutSheetDialog` pré-configurado com o `userId` do aluno sendo visualizado.

---

### BUG-04 — `create_workout_sheet_dialog.dart`: `user_id` Pode Apontar para o Trainer

**Localização:** `frontend/lib/screens/trainer/widgets/create_workout_sheet_dialog.dart`

**Suspeita:** Quando o Personal Trainer abre o dialog pelo botão `TrainerSheets` (sem contexto de aluno), a dialog obtém `user_id` via `AuthProvider` que retorna o usuário logado (o próprio trainer). Fichas criadas assim são atribuídas ao trainer, não a um aluno.

**Comportamento Esperado:** O dialog deve receber um `userId` explícito do aluno como parâmetro. Se não fornecido, deve exibir um campo/dropdown para selecionar o aluno.

**Verificar:** Confirmar se o campo `userId` do dialog está sendo obtido via context (trainer) ou via parâmetro (aluno).

---

## 🎯 3. Escopo da Correção

### O que DEVE ser corrigido (In Scope)

| Bug | Arquivo Principal | Prioridade |
|-----|-------------------|------------|
| BUG-01 | `workouts_screen.dart` | 🔴 Crítico |
| BUG-02 | `workouts_screen.dart` | 🔴 Crítico |
| BUG-03 | `trainer_student_detail.dart` | 🟠 Alto |
| BUG-04 | `create_workout_sheet_dialog.dart` | 🟠 Alto |

### O que NÃO deve ser mudado (Out of Scope)

- ❌ Backend (está correto e completo)
- ❌ `workout_sheet_model.dart` (DTOs corretos)
- ❌ `workout_sheet_service.dart` (funciona)
- ❌ `workout_sheet_provider.dart` (funciona)
- ❌ `trainer_sheets.dart` (funcionando corretamente)
- ❌ `edit_workout_sheet_dialog.dart` (funcionando)
- ❌ `exercise_catalog_picker.dart` (funcionando)
- ❌ Dados mockados de Nutrição, Conquistas, Perfil (não são foco deste PRD)

---

## 🛠️ 4. Especificação Técnica das Correções

### CORREÇÃO BUG-01 e BUG-02 — Refatorar `workouts_screen.dart`

**Objetivo:** Conectar a tela do aluno à API real.

**Mudanças necessárias:**

1. **Remover** imports de `mock_data.dart` (classes `Workout` e `Exercise` locais).
2. **Adicionar** Consumer/Provider de `WorkoutSheetProvider`.
3. **No `initState`:** Chamar `provider.loadSheets()` com o `userId` do aluno logado (obtido via `AuthProvider`).
4. **Na ListView:** Iterar sobre `provider.sheets` (tipo `List<WorkoutSheetListItem>`) em vez de `workouts`.
5. **Card de ficha:** Exibir `dayOfWeekLabel`, `name`, `exerciseCount`.
6. **Na tela de detalhe/execução:** Ao tocar em um card, chamar `provider.loadSheetDetail(sheetId)` para buscar `WorkoutSheetResponse` com todos os exercícios.
7. **Na tela de execução:** Usar campos de `ExerciseResponse` (series, repetitions, loadKg, restSeconds, observations, gifUrl) em vez do modelo mock.
8. **Estados:** Tratar loading (`provider.isLoading`), erro (`provider.error`) e lista vazia.
9. **Pull-to-refresh:** Chamar `provider.loadSheets()` ao puxar a lista para baixo.

**Fluxo de Estado:**

```
initState()
├── context.read<WorkoutSheetProvider>().loadSheets(userId: authProvider.currentUser?.id)
│
build()
├── Consumer<WorkoutSheetProvider>(
│   ├── isLoading → CircularProgressIndicator
│   ├── error → ErrorWidget com botão "Tentar Novamente"
│   ├── sheets.isEmpty → EmptyStateWidget "Nenhuma ficha atribuída"
│   └── sheets.isNotEmpty → ListView com WorkoutSheetListItem cards
│       └── onTap → loadSheetDetail(sheet.id) → navegar para tela de execução
│           └── selectedSheet → ExerciseResponse com campos reais
```

**Campos a exibir por exercício na tela de execução:**

```dart
// Usar ExerciseResponse (modelo real), não Exercise (mock)
Text('${exercise.series}x${exercise.repetitions}')      // "4x8" 
Text('${exercise.loadKg}kg')                              // "60.0kg"
Text('Descanso: ${exercise.restSeconds}s')               // "Descanso: 90s"
Text(exercise.muscleGroup)                               // "peito"
if (exercise.gifUrl != null) Image.network(exercise.gifUrl!) // GIF demonstrativo
if (exercise.observations != null) Text(exercise.observations!) // observações
```

---

### CORREÇÃO BUG-03 — Implementar Botão "+ Novo" em `trainer_student_detail.dart`

**Objetivo:** Permitir que o Personal Trainer crie ficha diretamente na tela do aluno.

**Mudanças necessárias:**

```dart
// Em trainer_student_detail.dart, na Tab "Treinos":
ElevatedButton(
  onPressed: () async {
    // Abrir CreateWorkoutSheetDialog COM o studentId pré-configurado
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CreateWorkoutSheetDialog(
        targetUserId: widget.studentId,  // ← Passa o aluno correto
      ),
    );
    if (result == true) {
      // Recarregar fichas do aluno
      context.read<WorkoutSheetProvider>().loadSheets(userId: widget.studentId);
    }
  },
  child: const Text('+ Novo Treino'),
)
```

---

### CORREÇÃO BUG-04 — Adicionar Parâmetro `targetUserId` em `create_workout_sheet_dialog.dart`

**Objetivo:** Garantir que fichas sejam criadas para o aluno correto.

**Mudanças necessárias:**

```dart
class CreateWorkoutSheetDialog extends StatefulWidget {
  final String? targetUserId;  // Nullable: se null, mostrar seletor de aluno
  
  const CreateWorkoutSheetDialog({
    super.key,
    this.targetUserId,  // Quando chamado do TrainerStudentDetail, já vem preenchido
  });
}

// No método _submit():
final userId = widget.targetUserId ?? // Usa o aluno passado por parâmetro
               _selectedStudentId ??  // Ou aluno selecionado no dropdown
               authProvider.currentUser!.id; // Fallback (trainer) - apenas se trainer for aluno
```

**Se `targetUserId` for null** (quando chamado de `TrainerSheets`):
- Exibir um campo/seletor de aluno no formulário
- OU manter comportamento atual mas verificar se o usuário logado é um aluno (não o trainer)

---

## 📋 5. Contratos de API Utilizados

Os endpoints já existem e funcionam. A correção apenas conecta o frontend a eles:

| Endpoint | Uso na Correção |
|----------|----------------|
| `GET /api/v1/workout-sheets?user_id={id}` | BUG-01: Carregar fichas do aluno |
| `GET /api/v1/workout-sheets/{id}` | BUG-02: Carregar exercícios para execução |
| `POST /api/v1/workout-sheets` | BUG-03/04: Criar ficha para aluno |

**Response esperada ao listar fichas do aluno:**
```json
{
  "total": 3,
  "page": 1,
  "limit": 10,
  "data": [
    {
      "id": "uuid",
      "user_id": "aluno-uuid",
      "personal_trainer_id": "trainer-uuid",
      "name": "Treino A - Peito",
      "day_of_week": 0,
      "is_active": true,
      "exercise_count": 5,
      "created_at": "2026-05-05T10:00:00"
    }
  ]
}
```

---

## 🧪 6. Critérios de Teste

### Testes Manuais (Smoke Tests)

**Fluxo Principal (Happy Path):**
1. Fazer login como Personal Trainer
2. Navegar para TrainerStudentDetail de um aluno
3. Na tab Treinos, clicar "+ Novo Treino"
4. Criar ficha com nome "Treino Teste", Dia=Segunda, 2 exercícios
5. Ficha deve aparecer na lista do TrainerStudentDetail ✅
6. Fazer logout → Fazer login como o Aluno que recebeu a ficha
7. Navegar para WorkoutsScreen
8. Ficha "Treino Teste" deve aparecer na lista ✅
9. Clicar na ficha → Tela de execução com os 2 exercícios reais ✅
10. Informações de séries, repetições, carga e descanso corretas ✅

**Fluxo de Erro:**
1. Desligar o backend (docker compose down)
2. Tentar abrir WorkoutsScreen como Aluno
3. Deve exibir mensagem de erro "Erro de conexão" com botão "Tentar Novamente" ✅
4. Ligar backend, clicar "Tentar Novamente" → Lista carrega ✅

**Lista Vazia:**
1. Login como Aluno sem fichas atribuídas
2. WorkoutsScreen deve exibir estado vazio "Nenhuma ficha atribuída ainda" ✅

---

## 🎯 7. Definição de Pronto (DoD)

- [ ] `workouts_screen.dart` não importa mais `mock_data.dart` para fichas de treino
- [ ] `workouts_screen.dart` usa `WorkoutSheetProvider.loadSheets(userId: ...)` no initState
- [ ] Lista de fichas do aluno exibe `WorkoutSheetListItem` (dados reais da API)
- [ ] Tela de execução/detalhe usa `WorkoutSheetResponse` e `ExerciseResponse` (modelo real)
- [ ] Campos exibidos: series, repetitions, loadKg, restSeconds, muscleGroup, observations, gifUrl
- [ ] Estados tratados: loading, erro, lista vazia
- [ ] Pull-to-refresh funcional
- [ ] Botão "+ Novo" em `trainer_student_detail.dart` abre `CreateWorkoutSheetDialog` com `studentId`
- [ ] `CreateWorkoutSheetDialog` aceita parâmetro `targetUserId`
- [ ] Fichas criadas são atribuídas ao aluno correto (não ao trainer)
- [ ] Pull Request criado contra a branch `develop`

---

## 🔄 8. Workflow de Implementação

**Branch:** `fix/treinos-integracao-aluno`

**Sequência de Commits:**

```
fix(treinos): adicionar parâmetro targetUserId no CreateWorkoutSheetDialog

fix(treinos): implementar botão nova ficha no TrainerStudentDetail

fix(treinos): conectar WorkoutsScreen à API real (substituir mock)

fix(treinos): adaptar tela de execução para ExerciseResponse real
```

**Prompt para IA (se usar Claude):**
```
Claude, corrija os bugs de integração do módulo de treinos conforme
docs/PRD_CORRECAO_INTEGRACAO_TREINOS.md

Contexto:
- Backend: funcionando corretamente, 7 endpoints REST
- Frontend: WorkoutSheetProvider, WorkoutSheetService, workout_sheet_model.dart prontos
- Problema: workouts_screen.dart ainda usa mock_data.dart

Requisitos:
- BUG-01/02: Refatorar workouts_screen.dart para usar WorkoutSheetProvider
- BUG-03: Implementar botão "+ Novo" em trainer_student_detail.dart
- BUG-04: Adicionar parâmetro targetUserId em CreateWorkoutSheetDialog
- Não alterar backend nem os services/providers (já funcionam)
- Não alterar dados mockados de Nutrição/Conquistas (fora do escopo)

Padrão do projeto:
- Flutter + Provider (ChangeNotifier)
- Conventional commits em português
- Sem Co-Author nos commits
- Branch: fix/treinos-integracao-aluno

Output:
- Arquivos corrigidos
- PR criado contra develop
- Commit: fix(treinos): corrigir integração da tela do aluno com API
```

---

## 📊 9. Impacto e Riscos

| Risco | Probabilidade | Mitigação |
|-------|---------------|-----------|
| `AuthProvider` não expõe `currentUser.id` | Baixa | Verificar campo antes de implementar |
| `WorkoutSheetProvider` não aceita filtro por userId em loadSheets | Baixa | Já aceita: `loadSheets({userId?, dayOfWeek?})` |
| Aluno sem fichas travar em null | Média | Tratar lista vazia com EmptyStateWidget |
| GIF URLs inválidas travando Image.network | Média | Usar `errorBuilder` no Image.network |
| Incompatibilidade de parâmetros no dialog ao adicionar targetUserId | Baixa | Manter parâmetro como opcional (nullable) |

---

*OmniConnect Fitness - Documentação Técnica Interna*  
*Alpha EdTech - Turma Aurora*  
*Criado: 2026-05-05*
