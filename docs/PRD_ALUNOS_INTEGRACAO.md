# PRD: Integração do Módulo de Alunos (Frontend ↔ Backend)

## 1. Visão Geral (O que é?)

Este PRD detalha a implementação e integração do "Módulo de Alunos" para a interface do Personal Trainer (`TrainerStudentsScreen` e `TrainerStudentDetail`). Atualmente, o frontend exibe dados mockados (provenientes de `mock_data.dart`). O objetivo é consumir a API real para listar os alunos vinculados ao personal trainer logado e visualizar os detalhes de um aluno específico (incluindo progresso de metas, último treino, etc.).

## 2. Cenário Atual

- **Frontend:**
  - Telas `TrainerStudentsScreen` e `TrainerStudentDetail` dependem da classe `Student` e lista `students` definidas em `models/mock_data.dart`.
  - Serviço `UserService` (`lib/services/user_service.dart`) não possui um método para listar alunos.
- **Backend:**
  - O modelo `User` possui o campo `trainer_id` (`app/models/user.py`).
  - A rota `GET /api/v1/users` permite que `personal_trainer` liste usuários, mas o `UserService` não filtra atualmente os alunos pelo `trainer_id` do requisitante.

## 3. Requisitos da Funcionalidade

### 3.1. Backend (FastAPI + SQLAlchemy)

**1. Ajuste na Rota de Listagem de Usuários (`GET /api/v1/users`) ou Nova Rota:**

- **Opção Recomendada:** Criar uma rota dedicada `GET /api/v1/users/students` ou ajustar `GET /api/v1/users` para aceitar um query parameter `trainer_id` (que para um `personal_trainer` deve ser forçado ao seu próprio ID de usuário).
- **Lógica de Filtragem:** A query deve buscar na tabela `users` onde `role == 'client'` e `trainer_id == current_user.id`.
- **Response Esperado:** Lista de usuários (alunos) com campos como `id`, `name`, `email`, `goal_type`, `created_at`, além de informações auxiliares (ex: `last_session`, `progress` que podem ser calculados nos logs/metas ou mockados temporariamente se a complexidade for alta).

**2. Visualização de Detalhes do Aluno (`GET /api/v1/users/{id}`):**

- A rota atual já valida se o usuário solicitante é dono do ID ou tem role de `admin`/`personal_trainer`.
- **Validação de Segurança Adicional (opcional mas recomendada):** Garantir que um personal trainer só consiga visualizar os dados de usuários onde `trainer_id == current_user.id` (além de administradores).

### 3.2. Frontend (Flutter)

**1. Serviço de API (`UserService` e possivelmente `GoalService`/`WorkoutSheetService`):**

- Criar método `getStudents()` em `UserService` (`lib/services/user_service.dart`) que faz um GET para a rota de listagem de alunos do personal trainer.
- Criar método para obter os detalhes completos do aluno (caso a listagem traga dados reduzidos).

**2. Tela `TrainerStudentsScreen`:**

- Remover dependência de `mock_data.dart`.
- Adicionar estado (FutureBuilder ou Provider/Bloc) para buscar a lista de alunos do backend.
- Exibir estado de carregamento (`CircularProgressIndicator`) enquanto aguarda os dados.
- Mapear a resposta do backend (nome do aluno, objetivo principal `goal_type`) para o visual da lista.

**3. Tela `TrainerStudentDetail`:**

- Buscar dados detalhados do aluno selecionado no backend (incluindo treinos atribuídos, progresso de metas, etc., combinando dados de `UserService`, `WorkoutSheetService` e `GoalService`).
- Remover chamadas ao mock e exibir os dados reais do banco de dados.

## 4. Estrutura de Dados e Endpoints

### Endpoint Backend: Listar Alunos do Trainer

- **Method:** `GET`
- **URL:** `/api/v1/users` (com param `trainer_id=self`) ou `/api/v1/users/students`
- **Response DTO:** `PaginatedUsersResponseDTO` (já existente), porém retornando apenas clients atrelados ao trainer.

### Modelo Frontend (Atualização)

- Criar um `StudentResponse` em Dart (ou utilizar `UserResponse` existente com campos extras para acomodar progresso e metadados).
  
```dart
class StudentResponse {
  final String id;
  final String name;
  final String? goalType; // Mapear para "goal" no app
  // ... outros campos (lastSession, progress podem vir agregados ou buscar separadamente)
}
```

## 5. Validações e Tratamento de Erros

### 5.1. Backend

- **Autorização (Role):** Garantir que a nova rota ou a adaptação da listagem recuse acessos de quem não possui a role `personal_trainer` (ou `admin`). Retornar `403 Forbidden` caso contrário.
- **Controle de Acesso (IDOR):** Na rota de detalhes (`GET /api/v1/users/{id}`), validar rigorosamente se o `trainer_id` do aluno solicitado corresponde ao ID do `personal_trainer` autenticado. Retornar `403 Forbidden` ou `404 Not Found` se tentar acessar um aluno de outro personal.
- **Paginação Segura:** Validar parâmetros de query `page` (>= 1) e `limit` (entre 1 e 100) para evitar consultas excessivamente pesadas.

### 5.2. Frontend

- **Tratamento de Exceções:** Implementar blocos `try/catch` no `UserService` e repassar os erros corretamente para a UI (ex: exibir um `SnackBar` com mensagem amigável se a API falhar).
- **Empty States (Estado Vazio):** Se a API retornar uma lista vazia (`data: []`), exibir uma mensagem visual clara (ex: "Você ainda não possui alunos vinculados.") em vez de uma tela em branco.
- **Loading States:** Mostrar um indicador de carregamento (`CircularProgressIndicator` ou Skeleton loaders) enquanto os dados são buscados, evitando ações prematuras do usuário na tela.

## 6. Critérios de Aceite (Definição de "Pronto")

- ✅ Endpoint no backend retorna exclusivamente os alunos (`client`) vinculados ao `personal_trainer` logado.
- ✅ O método `getStudents()` está implementado em `UserService` no frontend.
- ✅ `TrainerStudentsScreen` lista alunos reais provenientes da API, e o filtro de busca local continua funcionando.
- ✅ `TrainerStudentDetail` exibe os dados corretos do usuário clicado (id real).
- ✅ Nenhuma informação estática relacionada a alunos advinda de `mock_data.dart` permanece nas telas de alunos do trainer.
- ✅ Os testes automatizados (unitários e de integração do backend) para a nova rota/filtro foram implementados e rodam com sucesso (`>= 80%` cobertura).

## 7. Fluxo de Desenvolvimento e Versionamento

Para implementar este PRD, siga estritamente os padrões do projeto estabelecidos nas documentações (`BRANCH_STRATEGY.md`, `COMMIT_GUIDE.md`, `CLAUDE.md` e `GIT_TROUBLESHOOTING.md`):

### 7.1. Criação da Branch

- Certifique-se de estar na branch `develop` e atualizada (`git checkout develop && git pull`).
- Crie uma nova branch usando o prefixo adequado (GitHub Flow):

  ```bash
  git checkout -b feat/integracao-alunos
  ```

### 7.2. Padrão de Commits (Conventional Commits)

- Siga o formato: `<tipo>(<escopo>): <descrição>` (tudo em minúsculo, no imperativo, em português e sem ponto final).
- **Sem assinaturas:** Garanta que a configuração do Claude não adicione `Co-authored-by`.
- **Exemplos de Commits para esta task:**
  - `feat(backend): adicionar filtro por trainer_id na listagem de usuários`
  - `test(backend): adicionar testes para rota de listagem de alunos`
  - `feat(frontend): integrar tela de alunos com a api real`
  - `refactor(frontend): remover mocks de alunos do arquivo de mock_data`

### 7.3. Finalização e Pull Request

- Suba as alterações para o repositório:

  ```bash
  git push -u origin feat/integracao-alunos
  ```

- **Criação do PR:** Crie um Pull Request (ex: `gh pr create --base develop`) descrevendo claramente o que foi feito. O PR deve obrigatoriamente apontar para a branch `develop`.
- **⚠️ REGRA CRÍTICA (CLAUDE/IA):** O seu papel (IA) se encerra APÓS a criação do Pull Request. **Você deve criar o PR e finalizar sua execução.** Em hipótese nenhuma você deve tentar aprovar o PR, interagir com ele ou fazer o merge. A revisão, aprovação e o merge final serão feitos exclusivamente por outro colega da equipe.
