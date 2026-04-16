# Setup do Frontend Flutter — OmniConnect Fitness

## 📋 O que foi criado

A estrutura base do frontend Flutter foi inicializada em `frontend/` com:

### ✅ Arquivos Criados

**Tema e Design:**
- `lib/theme/app_colors.dart` — Paleta de cores (verde + escuro)
- `lib/theme/app_theme.dart` — Tema Material 3 escuro

**Rotas e Navegação:**
- `lib/routes/app_routes.dart` — Todas as rotas mapeadas com go_router

**Telas Autenticação:**
- `lib/screens/auth/splash_screen.dart` — Tela inicial (animada)
- `lib/screens/auth/login_screen.dart` — Login com email/senha
- `lib/screens/auth/register_screen.dart` — Cadastro de novo usuário

**Telas Aluno (Student):**
- `lib/screens/student/home_screen.dart` — Dashboard principal ✨ (completa)
- `lib/screens/student/workouts_screen.dart` — Fichas de treino (placeholder)
- `lib/screens/student/nutrition_screen.dart` — Plano alimentar (placeholder)
- `lib/screens/student/logbook_screen.dart` — Registro de exercícios (placeholder)
- `lib/screens/student/metrics_screen.dart` — Métricas e progresso (placeholder)
- `lib/screens/student/goals_screen.dart` — Metas (placeholder)
- `lib/screens/student/chat_screen.dart` — Chat com IA (placeholder)
- `lib/screens/student/profile_screen.dart` — Perfil do usuário (placeholder)

**Configuração:**
- `lib/main.dart` — Ponto de entrada (refatorado)
- `pubspec.yaml` — Dependências (atualizado)
- `Dockerfile` — Deploy em container
- `nginx.conf` — Configuração web
- `.env.example` — Variáveis de ambiente

## 🚀 Próximos Passos

### 1. Instale as dependências
```bash
cd frontend
flutter pub get
```

### 2. Rode o app
```bash
flutter run -d chrome      # Web
flutter run -d emulator    # Android
```

### 3. Complete as telas placeholders
Cada tela marcada com `⏳` precisa ser desenvolvida seguindo o protótipo do Lovable. As mais importantes são:
- `workouts_screen.dart` — Deve listar e permitir começar treino
- `nutrition_screen.dart` — Gráfico de macros + refeições do dia
- `logbook_screen.dart` — Histórico de treinos realizados
- `profile_screen.dart` — Dados do usuário + edição

### 4. Conecte com o Backend
Em `lib/services/`, crie arquivos como:
- `auth_service.dart` — Login/Logout/Registro
- `workout_service.dart` — Buscar fichas, atualizar logbook
- `nutrition_service.dart` — Buscar plano, refeições
- `user_service.dart` — Perfil, dados pessoais

### 5. Implemente State Management
Use `Provider` para gerenciar:
- Usuário logado
- Estado de autenticação
- Dados de treino/nutrição
- Notificações

## 📁 Estrutura Padrão

Ao criar novas telas, siga este padrão:

```
lib/screens/[perfil]/[funcionalidade]_screen.dart
```

Exemplo:
```
lib/screens/trainer/students_screen.dart
lib/screens/admin/dashboard_screen.dart
```

## 🎨 Usando o Tema

```dart
import 'package:omniconnect_fitness/theme/app_colors.dart';

// Cores
Container(
  color: AppColors.primary,
  child: Text(
    'Texto',
    style: Theme.of(context).textTheme.bodyLarge,
  ),
)
```

## 🔧 Adicionando Dependências

```bash
flutter pub add nome_do_pacote
```

Dependências principais já instaladas:
- `go_router` — Navegação
- `provider` — State management
- `http` — Requisições HTTP
- `animate_do` — Animações
- `google_fonts` — Fontes customizadas

## 📱 Telas Prioritárias para MVP

1. ✅ Splash + Login + Register
2. ✅ Home (Dashboard)
3. 🔴 Workouts (IMPORTANTE)
4. 🔴 Logbook (IMPORTANTE)
5. 🔴 Nutrition (IMPORTANTE)
6. 🟡 Profile
7. 🟡 Chat IA

## 🐳 Deploy com Docker

```bash
cd frontend
docker build -t omniconnect-frontend .
docker run -p 3000:80 omniconnect-frontend
# Acesse em http://localhost:3000
```

## 📞 Contato com Backend

**API Base URL:** `http://localhost:8000`
**Docs:** `http://localhost:8000/docs`

Faça requisições assim:

```dart
import 'package:http/http.dart' as http;

Future<void> loginUser(String email, String password) async {
  final response = await http.post(
    Uri.parse('http://localhost:8000/api/auth/login'),
    body: {'email': email, 'password': password},
  );
  
  if (response.statusCode == 200) {
    // Sucesso
  }
}
```

---

**Próxima reunião:** Definir data para começar a codificar as telas prioritárias.
