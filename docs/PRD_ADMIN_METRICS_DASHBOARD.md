# PRD: Dashboard de Métricas Administrativas
## OmniConnect Fitness — Admin Metrics Dashboard

**Versão:** 1.0  
**Data:** 2026-05-12  
**Status:** ✅ Aprovado para Implementação  
**Backend:** ✅ Implementado — [ADMIN_DASHBOARD_SPEC.md](ADMIN_DASHBOARD_SPEC.md)  
**Endpoints disponíveis:**
- `GET /api/v1/admin/metrics/students`
- `GET /api/v1/admin/metrics/trainers`
- `GET /api/v1/admin/metrics/system`
- `GET /api/v1/admin/metrics/ai`

---

## 1. Visão Geral

### 1.1 Problema
O admin hoje gerencia trainers e alunos em telas CRUD básicas (`AdminDashboardScreen`). Faltam **insights de negócio**: quem está em risco de churn, quais trainers performam melhor, quanto está custando a IA. Sem dados, decisões são baseadas em intuição.

### 1.2 Solução
Adicionar uma nova aba **"Métricas"** no `AdminShell` com 4 cards de KPI que consomem os endpoints de analytics implementados no backend.

### 1.3 Objetivo de Negócio
- Reduzir churn identificando alunos em risco antes que cancelem
- Identificar trainers top performers vs que precisam de suporte
- Monitorar custo de IA em relação ao engajamento

---

## 2. Escopo

### Incluído nesta versão (MVP)
- [x] Tela principal do dashboard (`AdminMetricsDashboardScreen`)
- [x] 4 cards de métricas (alunos, trainers, sistema, IA)
- [x] Filtro de período (7, 14, 30, 90 dias)
- [x] Filtro de trainer para card de alunos
- [x] Exportação CSV de dados de alunos
- [x] Modal "Alunos em Risco" com ações rápidas
- [x] Navegação via nova aba no AdminShell

### Fora do escopo (Fase 2)
- Exportação PDF com gráficos
- Alertas push automáticos para churn
- Dashboards customizáveis
- Cache local dos dados

---

## 3. Especificação de Navegação

### 3.1 Integração com AdminShell

Adicionar 4ª aba no `admin_shell.dart`:

```
Aba 0: Trainers  → /admin/trainers     (já existe)
Aba 1: WhatsApp  → /admin/whatsapp     (já existe)
Aba 2: Métricas  → /admin/metrics      (NOVO)
Aba 3: Config    → /admin/settings     (já existe)
```

**Ícone da aba:**
- Icon padrão: `Icons.analytics_outlined`
- Icon selecionado: `Icons.analytics`
- Label: `"Métricas"`

### 3.2 Nova rota no GoRouter

Em `app_routes.dart`, dentro do ShellRoute do admin:

```dart
GoRoute(
  path: '/admin/metrics',
  builder: (context, state) => const AdminMetricsDashboardScreen(),
),
```

---

## 4. Especificação de UI

### 4.1 Estrutura da Tela Principal

```
AdminMetricsDashboardScreen
├── OmniAppBar (title: "Métricas", actions: [RefreshButton])
├── PeriodFilterBar (sticky no topo, scroll)
│   └── Chips: [7d | 14d | 30d* | 90d]
└── ScrollView
    ├── SystemHealthCard
    ├── StudentMetricsCard
    ├── TrainerMetricsCard
    └── AIAnalyticsCard
```

### 4.2 PeriodFilterBar

**Comportamento:**
- Chips horizontais com scroll horizontal
- Chip selecionado: cor `context.colors.primary` + texto branco
- Chip não selecionado: outlined com `context.colors.border`
- 30 dias é o padrão (selecionado ao abrir)
- Ao selecionar novo período, atualiza **todos os cards** simultaneamente

**UI:**
```
┌─────────────────────────────────────────────────────┐
│  [  7d  ]  [  14d  ]  [ ●30d● ]  [  90d  ]         │
└─────────────────────────────────────────────────────┘
```

---

### 4.3 Card 1 — SystemHealthCard

**Posição:** Primeiro card (visão geral)  
**Dimensões:** Full width, altura ~160px

**Layout:**
```
┌─────────────────────────────────────────────────────┐
│  📈 Saúde do Sistema              Últimos 30 dias   │
├──────────────────┬──────────────────────────────────┤
│  DAU: 312         │   Novos Usuários: 45             │
│  MAU: 487         │   Treinos Completados: 1.234     │
│  📊 DAU/MAU: 0.64 │   Logs de Dieta: 892             │
│  ▲ Engajamento    │                                   │
│    Excelente      │   Chatbot Adoção: 34.5%          │
│                   │   Qualidade IA: 82.3%            │
└──────────────────┴──────────────────────────────────┘
```

**Componentes:**
- `OmniCard` com padding 16
- Grid 2 colunas com 6 `_MetricTile` (label + valor)
- DAU/MAU ratio com indicador colorido:
  - `≥ 0.5` → `accentSuccess` (verde) + "Excelente"
  - `0.3–0.5` → `accentWarning` (amarelo) + "Bom"
  - `< 0.3` → `accentError` (vermelho) + "Em Risco"

**Estado de loading:**
- `OmniLoader` centralizado durante fetch
- Dados são exibidos após carregar (sem skeleton)

---

### 4.4 Card 2 — StudentMetricsCard

**Posição:** Segundo card  
**Dimensões:** Full width, altura variável (tem lista paginada)

**Layout:**
```
┌─────────────────────────────────────────────────────┐
│  🎓 Alunos                  [Filtrar ▾] [Exportar ↓] │
├─────────────────────────────────────────────────────┤
│  Resumo:                                             │
│   ● Alta Adesão: 145    ● Churn Risk: 12            │
│   ● Média: 89           ● Aderência Média: 76.5%    │
├─────────────────────────────────────────────────────┤
│  🔴 8 Críticos  🟠 12 Alto  🟡 14 Médio  🟢 ___    │
├─────────────────────────────────────────────────────┤
│  [🔍 Buscar aluno]                   [Ver em risco] │
├─────────────────────────────────────────────────────┤
│  [Lista de alunos paginada]                         │
│   João Silva    ████████░░ 80%   🟢 low    [→]     │
│   Maria Santos  ████░░░░░░ 40%   🔴 critical [→]   │
│   ...                                               │
└─────────────────────────────────────────────────────┘
```

**Sub-componentes:**

**SummaryRow:**
- 4 `OmniStatCard` em grid 2×2
- Valores: total_students, avg_adherence_rate, at_risk_critical, high_adherence_count

**RiskBreakdownRow:**
- 4 chips coloridos com contagem por risk_level
- Tap em qualquer chip filtra a lista

**SearchAndActions:**
- `OmniTextField` para busca por nome (filtra localmente)
- Botão "Ver em Risco" → abre `AtRiskStudentsBottomSheet`

**StudentListTile (item da lista):**
```
[OmniAvatar]  [Name]          [ProgressBar]  [Badge]  [→]
              [last_activity] [XX%]          [risk]
```
- `OmniProgressBar` colorida conforme categoria (verde/amarelo/vermelho)
- `OmniStatusBadge` com risk_level
- Tap → abre `AdminStudentDetailScreen` (rota existente ou nova)
- Paginação: "Ver mais" button (carrega próxima página)

**Filtro dropdown:**
- Filtrar por trainer específico (lista de trainers do provider existente)
- Reset para "Todos os trainers"

**Exportação CSV:**
- Botão `Icons.download` no header
- Ao clicar → gera CSV em memória e chama `share_plus` ou download no web
- Colunas: nome, trainer, adherence_rate, risk_level, last_activity, sessions_completed, diet_logs_count

---

### 4.5 Card 3 — TrainerMetricsCard

**Posição:** Terceiro card  
**Dimensões:** Full width, altura variável (lista)

**Layout:**
```
┌─────────────────────────────────────────────────────┐
│  💼 Personal Trainers                               │
├─────────────────────────────────────────────────────┤
│  [Lista com ranking de trainers]                    │
│                                                     │
│  #1  Ana Silva         ████████████ 84% health     │
│       45 alunos • 8 em risco                       │
│       Conversão: 70% • Aderência média: 72.3%      │
│                                                     │
│  #2  Carlos Melo       ████████░░░░ 70% health     │
│       32 alunos • 12 em risco                      │
│       Conversão: 55% • Aderência média: 65.1%      │
│  ...                                               │
└─────────────────────────────────────────────────────┘
```

**TrainerRankCard (item da lista):**
```
[OmniAvatar(rank#)]  [Name]              [HealthBar]
                     [X alunos | Y risco]  [%]
                     [Conversão: Z%]
```

**Indicador Visual portfolio_health:**
- Barra de progresso colorida:
  - `> 80%` → verde (`accentSuccess`)
  - `50–80%` → amarelo (`accentWarning`)
  - `< 50%` → vermelho (`accentError`)
- Valor percentual ao lado

**Ordenação:**
- Default: por `total_students` desc (maior carteira primeiro)
- Toggle: botão para ordenar por `portfolio_health` ou `conversion_rate`

---

### 4.6 Card 4 — AIAnalyticsCard

**Posição:** Quarto card (último)  
**Dimensões:** Full width, altura ~200px

**Layout:**
```
┌─────────────────────────────────────────────────────┐
│  🤖 Analytics de IA                                 │
├──────────────┬──────────────────────────────────────┤
│ Total Msgs:  │  Modelos utilizados:                 │
│ 2.341        │                                      │
│              │  claude-sonnet  ████████    65%      │
│ Total Tokens:│  gpt-4          ████░░░░    35%      │
│ 1.234.567    │                                      │
│              │  Latência média: 1.240ms             │
│ Qualidade:   │  Tokens/msg: 527                     │
│ 82.3% ✓      │                                      │
└──────────────┴──────────────────────────────────────┘
```

**Componentes:**
- Coluna esquerda: 3 `_MetricTile` (msgs, tokens, quality)
- Coluna direita: `by_model` como mini barras de progresso
- Qualidade com ícone ✓ verde (se > 70%) ou ✗ vermelho (se < 70%)

**by_model rendering:**
- Para cada modelo: `[label]  [LinearProgressIndicator]  [XX%]`
- Cores alternadas entre `primary` e `accentInfo`

---

### 4.7 AtRiskStudentsBottomSheet

**Trigger:** Botão "Ver em Risco" no StudentMetricsCard  
**Tipo:** `showModalBottomSheet` com `isScrollControlled: true`

**Layout:**
```
┌─────────────────────────────────────────────────────┐
│  ⚠️ Alunos em Risco                           ──── │
│  8 críticos · 12 alto · 14 médio                   │
├─────────────────────────────────────────────────────┤
│  [Abas: Crítico | Alto | Médio]                     │
├─────────────────────────────────────────────────────┤
│  Lista filtrada por aba selecionada:                │
│                                                     │
│  🔴 Maria Santos         Trainer: Ana Silva         │
│     Adesão: 22.5%  •  Inativa há 8 dias            │
│     [Enviar Lembrete]   [Ver Perfil]                │
│                                                     │
│  🔴 Pedro Costa          Trainer: Carlos Melo       │
│     Adesão: 18%  •  Inativa há 12 dias             │
│     [Enviar Lembrete]   [Ver Perfil]                │
└─────────────────────────────────────────────────────┘
```

**Abas:** `DefaultTabController` com 3 tabs (Crítico/Alto/Médio)  
**Item da lista:** `AtRiskStudentTile`  
**Ação "Enviar Lembrete":**
- Exibe `SnackBar` de confirmação
- Chama endpoint `POST /api/v1/notifications/send-reminder` (Fase 2 se não existir)
- Se endpoint não existir, exibir: `"Notificação registrada — será enviada em breve"`

---

### 4.8 ExportCsvDialog

**Trigger:** Botão de exportação no StudentMetricsCard

**Comportamento:**
1. Busca **todos** os dados do endpoint (sem paginação, ou com limit alto)
2. Gera string CSV em memória
3. No **Flutter Web**: usa `dart:html` para download automático
4. No **Mobile**: usa `share_plus` para compartilhar arquivo

**Formato CSV:**
```
Nome,Trainer,Aderência (%),Risk Level,Última Atividade,Treinos Completados,Logs de Dieta
João Silva,Ana Silva,85.3,low,2026-05-12,12,28
Maria Santos,Carlos Melo,22.5,critical,2026-05-04,2,5
```

**Filename:** `omniconnect_alunos_YYYY-MM-DD.csv`

---

## 5. Arquitetura de Código

### 5.1 Novos Arquivos (seguir padrão do projeto)

```
frontend/lib/
├── models/
│   └── admin_metrics_models.dart          ← DTOs para as 4 responses
├── services/
│   └── admin_metrics_service.dart         ← chamadas HTTP
├── providers/
│   └── admin_metrics_provider.dart        ← ChangeNotifier
└── screens/admin/
    ├── admin_metrics_dashboard_screen.dart ← tela principal
    └── widgets/
        ├── system_health_card.dart
        ├── student_metrics_card.dart
        ├── trainer_metrics_card.dart
        ├── ai_analytics_card.dart
        └── at_risk_students_sheet.dart
```

### 5.2 Arquivos Modificados

```
frontend/lib/
├── screens/admin/admin_shell.dart          ← adicionar aba "Métricas"
├── routes/app_routes.dart                  ← adicionar /admin/metrics
└── main.dart                               ← registrar AdminMetricsProvider
```

---

## 6. Especificação de Models (admin_metrics_models.dart)

```dart
// Segue exatamente o schema dos endpoints backend

class StudentMetricsItemDTO {
  final String userId;
  final String userName;
  final String? trainerId;
  final String? trainerName;
  final double adherenceRate;        // % de adesão
  final String adherenceCategory;   // "high" | "medium" | "low"
  final int sessionsCompleted;
  final int sessionsTotal;
  final int dietLogsCount;
  final String riskLevel;            // "critical" | "high" | "medium" | "low"
  final int riskScore;
  final int daysInactive;
  final DateTime? lastActivity;
  final double? goalProgress;

  factory StudentMetricsItemDTO.fromJson(Map<String, dynamic> json) { ... }
}

class StudentMetricsSummaryDTO {
  final int totalStudents;
  final int highAdherenceCount;
  final int mediumAdherenceCount;
  final int lowAdherenceCount;
  final double avgAdherenceRate;
  final int atRiskCritical;
  final int atRiskHigh;
  final int atRiskMedium;
  final int atRiskLow;

  factory StudentMetricsSummaryDTO.fromJson(Map<String, dynamic> json) { ... }
}

class PaginatedStudentMetricsDTO {
  final int total, page, limit;
  final List<StudentMetricsItemDTO> data;
  final StudentMetricsSummaryDTO summary;

  factory PaginatedStudentMetricsDTO.fromJson(Map<String, dynamic> json) { ... }
}

class TrainerMetricsItemDTO {
  final String trainerId;
  final String trainerName;
  final int totalStudents;
  final int activeStudents;
  final int atRiskStudents;
  final double portfolioHealth;
  final double avgStudentAdherence;
  final int invitesGenerated;
  final int invitesUsed;
  final double conversionRate;

  factory TrainerMetricsItemDTO.fromJson(Map<String, dynamic> json) { ... }
}

class PaginatedTrainerMetricsDTO {
  final int total, page, limit;
  final List<TrainerMetricsItemDTO> data;

  factory PaginatedTrainerMetricsDTO.fromJson(Map<String, dynamic> json) { ... }
}

class SystemMetricsDTO {
  final int periodDays;
  final int totalUsers;
  final int activeUsers;
  final int newUsersInPeriod;
  final int totalTrainers;
  final int totalStudents;
  final int dau;
  final int mau;
  final double dauMauRatio;
  final int totalWorkoutsCompleted;
  final int totalDietLogs;
  final double chatbotAdoptionRate;
  final double chatbotQualityScore;

  factory SystemMetricsDTO.fromJson(Map<String, dynamic> json) { ... }
}

class AIModelStatsDTO {
  final String model;
  final int messagesCount;
  final int totalTokens;
  final double avgLatencyMs;
  final double percentOfTotal;

  factory AIModelStatsDTO.fromJson(Map<String, dynamic> json) { ... }
}

class AIAnalyticsDTO {
  final int periodDays;
  final int totalMessages;
  final int totalTokens;
  final double avgTokensPerMessage;
  final double avgLatencyMs;
  final double qualityScore;
  final List<AIModelStatsDTO> byModel;

  factory AIAnalyticsDTO.fromJson(Map<String, dynamic> json) { ... }
}
```

---

## 7. Especificação do Service (admin_metrics_service.dart)

```dart
class AdminMetricsService {
  final ApiClient _client;

  AdminMetricsService(this._client);

  Future<PaginatedStudentMetricsDTO> getStudentMetrics({
    int days = 30,
    String? trainerId,
    int page = 1,
    int limit = 50,
  }) async {
    final params = {
      'days': days.toString(),
      if (trainerId != null) 'trainer_id': trainerId,
      'page': page.toString(),
      'limit': limit.toString(),
    };
    return _client.get(
      '/admin/metrics/students',
      queryParams: params,
      fromJson: PaginatedStudentMetricsDTO.fromJson,
    );
  }

  Future<PaginatedTrainerMetricsDTO> getTrainerMetrics({
    int days = 30,
    int page = 1,
    int limit = 50,
  }) async { ... }

  Future<SystemMetricsDTO> getSystemMetrics({int days = 30}) async { ... }

  Future<AIAnalyticsDTO> getAIAnalytics({int days = 30}) async { ... }

  // Para exportação: busca todas as páginas
  Future<List<StudentMetricsItemDTO>> getAllStudentsForExport({
    int days = 30,
    String? trainerId,
  }) async {
    const limit = 200;
    final firstPage = await getStudentMetrics(
      days: days, trainerId: trainerId, page: 1, limit: limit,
    );
    final all = [...firstPage.data];
    final totalPages = (firstPage.total / limit).ceil();
    for (var p = 2; p <= totalPages; p++) {
      final page = await getStudentMetrics(
        days: days, trainerId: trainerId, page: p, limit: limit,
      );
      all.addAll(page.data);
    }
    return all;
  }
}
```

---

## 8. Especificação do Provider (admin_metrics_provider.dart)

```dart
class AdminMetricsProvider extends ChangeNotifier {
  final AdminMetricsService _service;

  AdminMetricsProvider(this._service);

  // ── State ──────────────────────────────────────────────────────
  int _selectedDays = 30;
  String? _selectedTrainerId;

  PaginatedStudentMetricsDTO? _studentMetrics;
  PaginatedTrainerMetricsDTO? _trainerMetrics;
  SystemMetricsDTO? _systemMetrics;
  AIAnalyticsDTO? _aiAnalytics;

  // Loading states independentes por card
  bool _loadingStudents = false;
  bool _loadingTrainers = false;
  bool _loadingSystem = false;
  bool _loadingAI = false;

  // Error states independentes por card
  String? _studentError;
  String? _trainerError;
  String? _systemError;
  String? _aiError;

  // Getters públicos
  int get selectedDays => _selectedDays;
  String? get selectedTrainerId => _selectedTrainerId;
  PaginatedStudentMetricsDTO? get studentMetrics => _studentMetrics;
  PaginatedTrainerMetricsDTO? get trainerMetrics => _trainerMetrics;
  SystemMetricsDTO? get systemMetrics => _systemMetrics;
  AIAnalyticsDTO? get aiAnalytics => _aiAnalytics;
  bool get loadingStudents => _loadingStudents;
  bool get loadingTrainers => _loadingTrainers;
  bool get loadingSystem => _loadingSystem;
  bool get loadingAI => _loadingAI;
  String? get studentError => _studentError;
  String? get trainerError => _trainerError;
  String? get systemError => _systemError;
  String? get aiError => _aiError;

  // ── Actions ────────────────────────────────────────────────────

  Future<void> loadAll() async {
    // Carrega todos os cards em paralelo (await Future.wait)
    await Future.wait([
      loadStudents(),
      loadTrainers(),
      loadSystem(),
      loadAI(),
    ]);
  }

  Future<void> changePeriod(int days) async {
    _selectedDays = days;
    notifyListeners();
    await loadAll();
  }

  Future<void> changeTrainerFilter(String? trainerId) async {
    _selectedTrainerId = trainerId;
    notifyListeners();
    await loadStudents();
  }

  Future<void> loadStudents({int page = 1}) async {
    _loadingStudents = true;
    _studentError = null;
    notifyListeners();
    try {
      _studentMetrics = await _service.getStudentMetrics(
        days: _selectedDays,
        trainerId: _selectedTrainerId,
        page: page,
      );
    } catch (e) {
      _studentError = e.toString();
    } finally {
      _loadingStudents = false;
      notifyListeners();
    }
  }

  Future<void> loadTrainers() async { ... /* mesmo padrão */ }
  Future<void> loadSystem() async { ... }
  Future<void> loadAI() async { ... }

  Future<String> exportStudentsCsv({String? trainerId}) async {
    final students = await _service.getAllStudentsForExport(
      days: _selectedDays,
      trainerId: trainerId ?? _selectedTrainerId,
    );
    return _buildCsv(students);
  }

  String _buildCsv(List<StudentMetricsItemDTO> students) {
    final header = 'Nome,Trainer,Aderência (%),Risk Level,Última Atividade,Treinos Completados,Logs de Dieta\n';
    final rows = students.map((s) {
      final lastActivity = s.lastActivity?.toIso8601String().split('T').first ?? 'N/A';
      return '${s.userName},${s.trainerName ?? "N/A"},${s.adherenceRate},${s.riskLevel},$lastActivity,${s.sessionsCompleted},${s.dietLogsCount}';
    }).join('\n');
    return header + rows;
  }
}
```

---

## 9. Integração com main.dart

Adicionar no `MultiProvider`:

```dart
// Em services (ProxyProvider):
ProxyProvider<ApiClient, AdminMetricsService>(
  update: (_, client, __) => AdminMetricsService(client),
),

// Em providers (ChangeNotifierProxyProvider):
ChangeNotifierProxyProvider<AdminMetricsService, AdminMetricsProvider>(
  create: (_) => AdminMetricsProvider(AdminMetricsService(ApiClient())),
  update: (_, service, __) => AdminMetricsProvider(service),
),
```

---

## 10. Integração com AdminShell (admin_shell.dart)

```dart
// Adicionar na lista de items do BottomNavigationBar:
BottomNavigationBarItem(
  icon: Icon(Icons.analytics_outlined),
  activeIcon: Icon(Icons.analytics),
  label: 'Métricas',
),

// Adicionar na lista de rotas:
final _routes = [
  '/admin/trainers',
  '/admin/whatsapp',
  '/admin/metrics',    // ← NOVO (índice 2)
  '/admin/settings',   // ← move para índice 3
];
```

---

## 11. Comportamento dos Estados

### 11.1 Estados por Card

Cada card gerencia seu estado de forma independente:

| Estado | Exibição |
|--------|----------|
| Loading inicial | `OmniLoader()` centralizado dentro do `OmniCard` |
| Erro | `OmniErrorState(message: _error, onRetry: _load...)` |
| Vazio | `OmniEmptyState(message: "Sem dados no período.")` |
| Dados | Conteúdo normal do card |

### 11.2 Refresh

- Botão de refresh (`Icons.refresh`) na `OmniAppBar`
- Chama `provider.loadAll()` (todos os cards simultâneos)
- Exibe `CircularProgressIndicator` pequeno no AppBar enquanto carrega

### 11.3 Mudança de Período

- Ao selecionar novo período: todos os cards mostram loading
- `Future.wait` garante que todos carregam em paralelo
- Se um card falhar, os outros continuam exibindo dados

---

## 12. Paleta de Cores Específica para Métricas

Usar as cores existentes do design system (`AppColors`):

| Métrica | Cor | Código |
|---------|-----|--------|
| High adherence | accentSuccess | `#3dba5e` |
| Medium adherence | accentWarning | `#ffc84d` |
| Low adherence / risk | accentError | `#ff6b6b` |
| DAU/MAU ratio bom | accentSuccess | `#3dba5e` |
| DAU/MAU ratio médio | accentWarning | `#ffc84d` |
| DAU/MAU ratio ruim | accentError | `#ff6b6b` |
| IA qualidade boa | accentSuccess | `#3dba5e` |
| IA qualidade baixa | accentError | `#ff6b6b` |
| Primary bars | primary | `#3dba5e` |
| Secondary bars | accentInfo | `#4db8ff` |

---

## 13. Critérios de Aceitação

### Funcional
- [ ] Aba "Métricas" aparece no AdminShell para usuário com role=admin
- [ ] 4 cards carregam dados reais do backend em paralelo
- [ ] Período filter atualiza todos os cards ao ser trocado
- [ ] Filtro por trainer filtra apenas a lista de alunos
- [ ] Modal "Alunos em Risco" agrupa por severidade
- [ ] Exportação CSV gera arquivo com dados corretos
- [ ] Botão refresh recarrega todos os cards
- [ ] Erros exibem `OmniErrorState` com botão de retry

### Visual
- [ ] Cards seguem o design system Omni (OmniCard, cores, textos)
- [ ] Barras de progresso com cor proporcional ao risco
- [ ] OmniStatusBadge com cores corretas por risk_level
- [ ] DAU/MAU ratio com indicador colorido de saúde
- [ ] Loading states com OmniLoader
- [ ] Responsivo: funciona em mobile e web

### Técnico
- [ ] Provider com loading states independentes por card
- [ ] CSV gerado em memória (sem dependência de servidor)
- [ ] Nenhum dado hardcoded (tudo vem do backend)
- [ ] Seguir padrão do projeto: ChangeNotifier + ProxyProvider

---

## 14. Ordem de Implementação Sugerida

1. **`admin_metrics_models.dart`** — DTOs com fromJson
2. **`admin_metrics_service.dart`** — chamadas HTTP
3. **Registrar no `main.dart`** — ProxyProvider + ChangeNotifierProxyProvider
4. **`admin_metrics_provider.dart`** — state management
5. **Cards individuais** (widgets isolados, testáveis):
   - `system_health_card.dart`
   - `ai_analytics_card.dart`
   - `trainer_metrics_card.dart`
   - `student_metrics_card.dart` (mais complexo)
6. **`at_risk_students_sheet.dart`** — modal
7. **`admin_metrics_dashboard_screen.dart`** — composição dos cards
8. **Integrar AdminShell + GoRouter**

---

## 15. Dependências Necessárias

Verificar se já estão em `pubspec.yaml`:

```yaml
# Já existentes (NÃO adicionar novamente):
dependencies:
  provider: ^X.X.X      # state management (já existe)
  go_router: ^X.X.X     # routing (já existe)
  http: ^X.X.X          # HTTP (já existe)
  animate_do: ^X.X.X    # animações (já existe)

# Adicionar se não existir para exportação:
  share_plus: ^X.X.X    # compartilhar arquivo no mobile
  # (Flutter Web usa dart:html — sem dependência)
```

---

## 16. Referências

- **Backend spec completa:** [ADMIN_DASHBOARD_SPEC.md](ADMIN_DASHBOARD_SPEC.md)
- **Endpoints implementados:** `backend/app/routes/admin_metrics.py`
- **Tela admin existente:** `frontend/lib/screens/admin/admin_dashboard_screen.dart`
- **Design system Omni:** `frontend/lib/shared/widgets/`
- **Cores:** `frontend/lib/theme/app_colors.dart`
- **Routing:** `frontend/lib/routes/app_routes.dart`
- **Injeção:** `frontend/lib/main.dart`
