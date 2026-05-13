import 'package:flutter/foundation.dart';
import '../models/admin_metrics_models.dart';
import '../services/admin_metrics_service.dart';

class AdminMetricsProvider extends ChangeNotifier {
  final AdminMetricsService _service;

  AdminMetricsProvider({required AdminMetricsService service})
      : _service = service;

  // ── Filtros ────────────────────────────────────────────────────────────────
  int _selectedDays = 30;
  String? _selectedTrainerId;
  int _studentsPage = 1;
  static const _studentsLimit = 20;

  int get selectedDays => _selectedDays;
  String? get selectedTrainerId => _selectedTrainerId;

  // ── Dados ──────────────────────────────────────────────────────────────────
  PaginatedStudentMetricsDTO? _studentMetrics;
  PaginatedTrainerMetricsDTO? _trainerMetrics;
  SystemMetricsDTO? _systemMetrics;

  PaginatedStudentMetricsDTO? get studentMetrics => _studentMetrics;
  PaginatedTrainerMetricsDTO? get trainerMetrics => _trainerMetrics;
  SystemMetricsDTO? get systemMetrics => _systemMetrics;

  // ── Loading (independente por card) ───────────────────────────────────────
  bool _loadingStudents = false;
  bool _loadingTrainers = false;
  bool _loadingSystem = false;

  bool get loadingStudents => _loadingStudents;
  bool get loadingTrainers => _loadingTrainers;
  bool get loadingSystem => _loadingSystem;
  bool get isLoading =>
      _loadingStudents || _loadingTrainers || _loadingSystem;

  // ── Erros (independente por card) ─────────────────────────────────────────
  String? _studentError;
  String? _trainerError;
  String? _systemError;

  String? get studentError => _studentError;
  String? get trainerError => _trainerError;
  String? get systemError => _systemError;

  // ── Paginação de alunos ────────────────────────────────────────────────────
  bool _hasMoreStudents = false;
  bool get hasMoreStudents => _hasMoreStudents;

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Carrega os 3 cards em paralelo.
  Future<void> loadAll() async {
    await Future.wait([
      loadStudents(resetPage: true),
      loadTrainers(),
      loadSystem(),
    ]);
  }

  /// Muda período e recarrega tudo.
  Future<void> changePeriod(int days) async {
    _selectedDays = days;
    notifyListeners();
    await loadAll();
  }

  /// Muda filtro de trainer (apenas afeta card de alunos).
  Future<void> changeTrainerFilter(String? trainerId) async {
    _selectedTrainerId = trainerId;
    notifyListeners();
    await loadStudents(resetPage: true);
  }

  Future<void> loadStudents({bool resetPage = false}) async {
    if (resetPage) {
      _studentsPage = 1;
      _studentMetrics = null;
    }
    _loadingStudents = true;
    _studentError = null;
    notifyListeners();
    try {
      final result = await _service.getStudentMetrics(
        days: _selectedDays,
        trainerId: _selectedTrainerId,
        page: _studentsPage,
        limit: _studentsLimit,
      );
      if (_studentsPage == 1) {
        _studentMetrics = result;
      } else {
        // Acumula páginas para "Ver mais"
        _studentMetrics = PaginatedStudentMetricsDTO(
          total: result.total,
          page: result.page,
          limit: result.limit,
          data: [...?_studentMetrics?.data, ...result.data],
          summary: result.summary,
        );
      }
      _hasMoreStudents =
          (_studentMetrics?.data.length ?? 0) < result.total;
    } catch (e) {
      _studentError = _friendlyError(e);
    } finally {
      _loadingStudents = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreStudents() async {
    if (!_hasMoreStudents || _loadingStudents) return;
    _studentsPage++;
    await loadStudents();
  }

  Future<void> loadTrainers() async {
    _loadingTrainers = true;
    _trainerError = null;
    notifyListeners();
    try {
      _trainerMetrics = await _service.getTrainerMetrics(days: _selectedDays);
    } catch (e) {
      _trainerError = _friendlyError(e);
    } finally {
      _loadingTrainers = false;
      notifyListeners();
    }
  }

  Future<void> loadSystem() async {
    _loadingSystem = true;
    _systemError = null;
    notifyListeners();
    try {
      _systemMetrics = await _service.getSystemMetrics(days: _selectedDays);
    } catch (e) {
      _systemError = _friendlyError(e);
    } finally {
      _loadingSystem = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Sessão expirada. Faça login novamente.';
    }
    if (msg.contains('403') || msg.contains('Forbidden')) {
      return 'Você não tem permissão para acessar essas métricas.';
    }
    if (msg.contains('conexão') || msg.contains('Network')) {
      return 'Sem conexão. Verifique sua internet.';
    }
    return 'Erro ao carregar dados. Tente novamente.';
  }
}
