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

  // Getters correspondentes
  FrequencyResponse? get frequencyResponse => _frequencyResponse;
  MuscleGroupDistributionResponse? get distributionResponse => _distributionResponse;
  ProgressionResponse? get progressionResponse => _progressionResponse;

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
}
