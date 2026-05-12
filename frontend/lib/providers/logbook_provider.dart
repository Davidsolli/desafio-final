import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/logbook_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Provider para gerenciar estado do logbook
class LogbookProvider extends ChangeNotifier {
  final LogbookService _logbookService;

  List<LogbookResponse> _sessions = [];
  bool _isLoading = false;
  String? _error;

  LogbookProvider({required LogbookService logbookService}) : _logbookService = logbookService;

  // Getters
  List<LogbookResponse> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasSessions => _sessions.isNotEmpty;

  /// Carrega todas as sessões do logbook
  Future<void> loadSessions({int limit = 10, int offset = 0}) async {
    try {
      _setLoading(true);
      _error = null;

      _sessions = await _logbookService.getLogbookSessions(limit: limit, offset: offset);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar logbook: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Cria uma nova sessão no logbook
  Future<void> createSession(CreateLogbookDTO dto) async {
    try {
      _setLoading(true);
      _error = null;

      final newSession = await _logbookService.createLogbookSession(dto);
      _sessions.insert(0, newSession);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao criar sessão: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza uma sessão do logbook
  Future<void> updateSession(String sessionId, CreateLogbookDTO dto) async {
    try {
      _setLoading(true);
      _error = null;

      final updatedSession = await _logbookService.updateLogbookSession(sessionId, dto);

      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        _sessions[index] = updatedSession;
      }
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao atualizar sessão: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Deleta uma sessão do logbook
  Future<void> deleteSession(String sessionId) async {
    try {
      _setLoading(true);
      _error = null;

      await _logbookService.deleteLogbookSession(sessionId);
      _sessions.removeWhere((s) => s.id == sessionId);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao deletar sessão: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Inicia uma nova sessão ativa de treino (Estilo Hevy)
  Future<Map<String, dynamic>> startActiveSession(String workoutSheetId) async {
    try {
      _setLoading(true);
      _error = null;
      final sessionData = await _logbookService.startActiveSession(workoutSheetId);
      return sessionData;
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao iniciar treino ativo: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Registra progresso de um exercício na sessão ativa
  Future<void> logSessionExercise({
    required String sessionId,
    required String exerciseId,
    required int actualSeries,
    required int actualRepetitions,
    required double actualLoadKg,
    required List<Map<String, dynamic>> seriesDetails,
    String? exerciseNotes,
    bool painOrDiscomfort = false,
    String? painDescription,
    String? modification,
    String status = 'completed',
  }) async {
    try {
      _error = null;
      await _logbookService.logSessionExercise(
        sessionId: sessionId,
        exerciseId: exerciseId,
        actualSeries: actualSeries,
        actualRepetitions: actualRepetitions,
        actualLoadKg: actualLoadKg,
        seriesDetails: seriesDetails,
        exerciseNotes: exerciseNotes,
        painOrDiscomfort: painOrDiscomfort,
        painDescription: painDescription,
        modification: modification,
        status: status,
      );
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao registrar exercício: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Finaliza e fecha a sessão de treino ativa
  Future<void> completeActiveSession({
    required String sessionId,
    String? notes,
    int? difficultyLevel,
    String? mood,
    String status = 'completed',
  }) async {
    try {
      _setLoading(true);
      _error = null;
      await _logbookService.completeActiveSession(
        sessionId: sessionId,
        notes: notes,
        difficultyLevel: difficultyLevel,
        mood: mood,
        status: status,
      );
      // Recarregar sessões para atualizar a listagem e os gráficos
      await loadSessions();
      await loadFrequency('weekly', limit: 12);
      await loadMuscleGroupDistribution(days: 30);
      // Atualiza PRs ao finalizar sessão
      try { await loadPersonalRecords(); } catch (_) {}
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao finalizar treino: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Define o estado de carregamento
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Limpa a mensagem de erro
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Limpa todas as sessões
  void clearSessions() {
    _sessions = [];
    _error = null;
    notifyListeners();
  }

  // Atributos adicionais para análise de progresso
  FrequencyResponse? _frequencyResponse;
  MuscleGroupDistributionResponse? _distributionResponse;
  ProgressionResponse? _progressionResponse;
  PersonalRecordsResponse? _personalRecordsResponse;
  VolumeLoadResponse? _volumeLoadResponse;

  // Getters correspondentes
  FrequencyResponse? get frequencyResponse => _frequencyResponse;
  MuscleGroupDistributionResponse? get distributionResponse => _distributionResponse;
  ProgressionResponse? get progressionResponse => _progressionResponse;
  PersonalRecordsResponse? get personalRecordsResponse => _personalRecordsResponse;
  VolumeLoadResponse? get volumeLoadResponse => _volumeLoadResponse;

  /// Carrega a frequência de treinos por período
  Future<void> loadFrequency(String period, {int? limit}) async {
    try {
      _setLoading(true);
      _error = null;
      _frequencyResponse = await _logbookService.getWorkoutFrequency(period: period, limit: limit);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar frequência de treinos: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega a distribuição por grupo muscular
  Future<void> loadMuscleGroupDistribution({int days = 30}) async {
    try {
      _setLoading(true);
      _error = null;
      _distributionResponse = await _logbookService.getMuscleGroupDistribution(days: days);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar distribuição de grupo muscular: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega o progresso de cargas de um exercício específico
  Future<void> loadExerciseProgression(String exerciseId, {int weeks = 8}) async {
    try {
      _setLoading(true);
      _error = null;
      _progressionResponse = await _logbookService.getExerciseProgression(exerciseId, weeks: weeks);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar progressão do exercício: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega os recordes pessoais de carga
  Future<void> loadPersonalRecords({int limit = 10}) async {
    try {
      _setLoading(true);
      _error = null;
      _personalRecordsResponse = await _logbookService.getPersonalRecords(limit: limit);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar recordes pessoais: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega o Volume Load semanal de um exercício
  Future<void> loadVolumeLoad(String exerciseId, {int weeks = 8}) async {
    try {
      _setLoading(true);
      _error = null;
      _volumeLoadResponse = await _logbookService.getVolumeLoad(exerciseId, weeks: weeks);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar Volume Load: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- MÉTODOS E ATRIBUTOS PARA ALUNOS (VISÃO DO PERSONAL) ---
  final Map<String, List<LogbookResponse>> _studentSessions = {};
  final Map<String, FrequencyResponse> _studentFrequency = {};
  final Map<String, MuscleGroupDistributionResponse> _studentDistribution = {};
  final Map<String, ProgressionResponse> _studentProgression = {}; // chave: "${studentId}_${exerciseId}"
  final Map<String, PersonalRecordsResponse> _studentPersonalRecords = {};
  final Map<String, VolumeLoadResponse> _studentVolumeLoad = {};

  List<LogbookResponse> getStudentSessions(String studentId) => _studentSessions[studentId] ?? [];
  FrequencyResponse? getStudentFrequency(String studentId) => _studentFrequency[studentId];
  MuscleGroupDistributionResponse? getStudentDistribution(String studentId) => _studentDistribution[studentId];
  ProgressionResponse? getStudentProgression(String studentId, String exerciseId) => _studentProgression['${studentId}_$exerciseId'];
  PersonalRecordsResponse? getStudentPersonalRecords(String studentId) => _studentPersonalRecords[studentId];
  VolumeLoadResponse? getStudentVolumeLoad(String studentId, String exerciseId) => _studentVolumeLoad['${studentId}_$exerciseId'];

  /// Carrega as sessões completadas do aluno
  Future<void> loadStudentSessions(String studentId, {int limit = 10, int offset = 0}) async {
    try {
      _setLoading(true);
      _error = null;
      _studentSessions[studentId] = await _logbookService.getLogbookSessions(limit: limit, offset: offset, userId: studentId);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar sessões do aluno: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega a frequência de treinos por período para o aluno
  Future<void> loadStudentFrequency(String studentId, String period, {int? limit}) async {
    try {
      _setLoading(true);
      _error = null;
      _studentFrequency[studentId] = await _logbookService.getWorkoutFrequency(period: period, limit: limit, userId: studentId);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar frequência de treinos do aluno: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega a distribuição muscular por período para o aluno
  Future<void> loadStudentMuscleGroupDistribution(String studentId, {int days = 30}) async {
    try {
      _setLoading(true);
      _error = null;
      _studentDistribution[studentId] = await _logbookService.getMuscleGroupDistribution(days: days, userId: studentId);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar foco muscular do aluno: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega a progressão de cargas do exercício selecionado para o aluno
  Future<void> loadStudentExerciseProgression(String studentId, String exerciseId, {int weeks = 8}) async {
    try {
      _setLoading(true);
      _error = null;
      _studentProgression['${studentId}_$exerciseId'] = await _logbookService.getExerciseProgression(exerciseId, weeks: weeks, userId: studentId);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar progressão do exercício do aluno: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega os recordes pessoais de carga para o aluno
  Future<void> loadStudentPersonalRecords(String studentId, {int limit = 10}) async {
    try {
      _setLoading(true);
      _error = null;
      _studentPersonalRecords[studentId] = await _logbookService.getPersonalRecords(limit: limit, userId: studentId);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar recordes pessoais do aluno: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega o Volume Load semanal de um exercício para o aluno
  Future<void> loadStudentVolumeLoad(String studentId, String exerciseId, {int weeks = 8}) async {
    try {
      _setLoading(true);
      _error = null;
      _studentVolumeLoad['${studentId}_$exerciseId'] = await _logbookService.getVolumeLoad(exerciseId, weeks: weeks, userId: studentId);
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar Volume Load do aluno: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
