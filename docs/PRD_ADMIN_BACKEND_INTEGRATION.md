# PRD: Integração Backend para Telas Admin

## Contexto
As telas de admin (dashboard de trainers, detalhes de alunos por trainer, formulários de cadastro/edição, configurações) estão implementadas com dados mockados. O backend já tem os endpoints necessários (`GET/PUT/POST /api/v1/users`) e o modelo `User` já possui `trainer_id` (FK para users.id) e `is_active`. O objetivo é conectar as telas ao backend real, seguindo os padrões do projeto: `ApiClient → Service → Provider → ChangeNotifier`.

---

## O que o backend já tem (sem alteração necessária)

| Endpoint | Uso nas telas Admin |
|---|---|
| `GET /api/v1/users?page=&limit=` | Listar todos os usuários |
| `GET /api/v1/users/{id}` | Detalhe de um usuário |
| `PUT /api/v1/users/{id}` | Editar trainer/aluno, ativar/desativar (`is_active`) |
| `POST /api/v1/users` | Criar novo trainer pelo admin |
| `GET /api/v1/users/me` | Dados do admin na tela Configurações |

---

## Backend — 1 ajuste necessário

O endpoint `GET /api/v1/users` não filtra por `role` ou `trainer_id`. Para listar apenas os personal trainers e, na tela de detalhes, listar apenas alunos de um trainer específico, precisamos adicionar query params de filtro.

### Arquivos a modificar

#### 1. `backend/app/routes/user.py`
Adicionar parâmetros opcionais na função `list_users`:
```python
role: Optional[str] = Query(None, description="Filtrar por role (admin, personal_trainer, client)"),
trainer_id: Optional[UUID] = Query(None, description="Filtrar alunos por trainer_id"),
```
Passar para o controller:
```python
return await controller.list_users(page=page, limit=limit, role=role, trainer_id=trainer_id)
```

#### 2. `backend/app/controllers/user_controller.py`
Adicionar `role` e `trainer_id` em `list_users()` e repassar ao service.

#### 3. `backend/app/services/user_service.py`
Adicionar `role` e `trainer_id` em `list_all()` e repassar ao repository.

#### 4. `backend/app/repositories/user_repository.py`
Adicionar filtros no `list_all()`:
```python
async def list_all(
    self,
    page: int = 1,
    limit: int = 10,
    role: Optional[str] = None,
    trainer_id: Optional[UUID] = None,
) -> Tuple[List[User], int]:
    query = select(User).where(User.is_active == True)
    if role:
        query = query.where(User.role == role)
    if trainer_id:
        query = query.where(User.trainer_id == trainer_id)
    # ... paginação existente
```

---

## Frontend — Arquivos a criar

### 1. `frontend/lib/models/admin_models.dart`
DTOs para o módulo admin:
```dart
class AdminUserDTO {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phoneWhatsapp;
  final String? trainerId;
  final bool isActive;
  final DateTime createdAt;

  factory AdminUserDTO.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

class CreateTrainerDTO {
  final String name;
  final String email;
  final String password;
  final String? phoneWhatsapp;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'password': password,
    'role': 'personal_trainer',
    if (phoneWhatsapp != null) 'phone_whatsapp': phoneWhatsapp,
  };
}

class UpdateAdminUserDTO {
  final String? name;
  final String? phoneWhatsapp;
  final bool? isActive;

  Map<String, dynamic> toJson(); // inclui apenas campos não-nulos
}

class PaginatedAdminUsersDTO {
  final int total;
  final List<AdminUserDTO> data;
  factory PaginatedAdminUsersDTO.fromJson(Map<String, dynamic> json);
}
```

### 2. `frontend/lib/services/admin_service.dart`
```dart
class AdminService {
  final ApiClient _api;
  AdminService({required ApiClient apiClient}) : _api = apiClient;

  Future<List<AdminUserDTO>> listTrainers() async {
    // GET /users?role=personal_trainer&limit=100
  }

  Future<List<AdminUserDTO>> listStudentsOfTrainer(String trainerId) async {
    // GET /users?trainer_id={trainerId}&limit=100
  }

  Future<AdminUserDTO> createTrainer(CreateTrainerDTO dto) async {
    // POST /users
  }

  Future<AdminUserDTO> updateUser(String userId, UpdateAdminUserDTO dto) async {
    // PUT /users/{userId}
  }

  Future<AdminUserDTO> toggleStatus(String userId, bool isActive) async {
    // PUT /users/{userId} com {is_active: !isActive}
  }

  Future<AdminUserDTO> getMe() async {
    // GET /users/me
  }

  Future<AdminUserDTO> updateMe(String userId, UpdateAdminUserDTO dto) async {
    // PUT /users/{userId}
  }
}
```

### 3. `frontend/lib/providers/admin_provider.dart`
```dart
class AdminProvider extends ChangeNotifier {
  final AdminService _service;

  List<AdminUserDTO> _trainers = [];
  List<AdminUserDTO> _studentsOfTrainer = [];
  AdminUserDTO? _currentAdmin;
  bool _isLoading = false;
  String? _error;

  // Getters públicos
  List<AdminUserDTO> get trainers => _trainers;
  List<AdminUserDTO> get studentsOfTrainer => _studentsOfTrainer;
  AdminUserDTO? get currentAdmin => _currentAdmin;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTrainers() async { ... }
  Future<void> loadStudentsOfTrainer(String trainerId) async { ... }
  Future<void> createTrainer(CreateTrainerDTO dto) async { ... }
  Future<void> toggleUserStatus(String userId, bool currentStatus) async { ... }
  Future<void> loadMe() async { ... }
  Future<void> updateMe(String userId, UpdateAdminUserDTO dto) async { ... }
}
```

---

## Frontend — Telas a modificar

### 4. `frontend/lib/screens/admin/admin_dashboard_screen.dart`
- Remover lista mock `trainers`
- `initState` → `context.read<AdminProvider>().loadTrainers()`
- Usar `Consumer<AdminProvider>` para exibir a lista
- Calcular `studentsCount` por trainer: chamar `listStudentsOfTrainer` para cada trainer OU adicionar um campo `studentsCount` calculado no provider
- Botão Ativar/Desativar → `provider.toggleUserStatus(trainer.id, trainer.isActive)`
- Botão Editar → passar `trainer.id` e dados reais para a rota `/admin/edit-trainer`

### 5. `frontend/lib/screens/admin/admin_pt_details_screen.dart`
- Remover lista mock `students`
- `initState` → `provider.loadStudentsOfTrainer(widget.trainerId)`
- Usar `Consumer<AdminProvider>` para exibir lista de alunos
- Ativar/Desativar → `provider.toggleUserStatus(student.id, student.isActive)`

### 6. `frontend/lib/screens/admin/admin_pt_form_screen.dart`
- Adicionar campo `trainerId` opcional no widget (para edição)
- Se `isEditing=false` → `provider.createTrainer(dto)` e voltar
- Se `isEditing=true` → `provider.updateUser(trainerId!, dto)` e voltar
- Mostrar loading durante a operação
- Mostrar erro se falhar

### 7. `frontend/lib/screens/admin/admin_settings_screen.dart`
- `initState` → `provider.loadMe()`
- Exibir dados reais de `provider.currentAdmin`
- Salvar → `provider.updateMe(currentAdmin.id, dto)`

---

## Injeção de Dependência — `frontend/lib/main.dart`

Adicionar junto aos outros providers existentes:
```dart
// Service
ProxyProvider<ApiClient, AdminService>(
  update: (_, apiClient, __) => AdminService(apiClient: apiClient),
),

// Provider
ChangeNotifierProxyProvider<AdminService, AdminProvider>(
  create: (_) => AdminProvider(service: AdminService(apiClient: ApiClient())),
  update: (_, service, prev) => AdminProvider(service: service),
),
```

---

## Rota `/admin/edit-trainer` — ajuste

Atualmente passa apenas o nome do trainer. Precisa passar o ID para poder fazer o PUT:
```dart
// Em admin_dashboard_screen.dart:
onTap: () => context.push('/admin/edit-trainer', extra: {
  'trainerId': trainer.id,
  'trainerName': trainer.name,
  // outros campos para pré-preencher o form
}),

// Em app_routes.dart:
GoRoute(
  path: adminEditTrainer,
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>?;
    return AdminPTFormScreen(
      isEditing: true,
      trainerId: extra?['trainerId'],
      trainerName: extra?['trainerName'],
    );
  },
),
```

---

## Ordem de implementação sugerida

1. **Backend** — adicionar filtros `role` e `trainer_id` (4 arquivos)
2. **Frontend models** — criar `admin_models.dart`
3. **Frontend service** — criar `admin_service.dart`
4. **Frontend provider** — criar `admin_provider.dart`
5. **DI** — registrar no `main.dart`
6. **Telas** — conectar uma a uma, testando com backend rodando

---

## Verificação

1. Docker up → login como admin
2. Tela Trainers → lista vinda da API (apenas `role=personal_trainer`)
3. Clicar trainer → alunos filtrados por `trainer_id`
4. Desativar trainer → `is_active=false`, badge "Inativo" aparece
5. Adicionar trainer → `POST /users` cria e reaparece na lista
6. Configurações → dados reais do admin logado, editar nome/telefone e salvar
