import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/goal_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Provider para gerenciar estado de metas
class GoalProvider extends ChangeNotifier {
  final GoalService _goalService;

  List<GoalResponse> _goals = [];
  bool _isLoading = false;
  String? _error;

  GoalProvider({required GoalService goalService}) : _goalService = goalService;

  // Getters
  List<GoalResponse> get goals => _goals;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasGoals => _goals.isNotEmpty;

  /// Carrega todas as metas do usuário
  Future<void> loadGoals({String? status}) async {
    try {
      _setLoading(true);
      _error = null;

      _goals = await _goalService.getGoals(status: status);
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
      _error = 'Erro ao carregar metas: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Cria uma nova meta
  Future<void> createGoal(CreateGoalDTO dto) async {
    try {
      _setLoading(true);
      _error = null;

      final newGoal = await _goalService.createGoal(dto);
      _goals.add(newGoal);
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
      _error = 'Erro ao criar meta: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza progresso de uma meta
  Future<void> updateGoalProgress(String goalId, double currentValue) async {
    try {
      _setLoading(true);
      _error = null;

      final updatedGoal = await _goalService.updateGoal(goalId, currentValue);

      final index = _goals.indexWhere((g) => g.id == goalId);
      if (index != -1) {
        _goals[index] = updatedGoal;
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
      _error = 'Erro ao atualizar meta: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Deleta uma meta
  Future<void> deleteGoal(String goalId) async {
    try {
      _setLoading(true);
      _error = null;

      await _goalService.deleteGoal(goalId);
      _goals.removeWhere((g) => g.id == goalId);
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
      _error = 'Erro ao deletar meta: ${e.toString()}';
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

  /// Limpa todas as metas
  void clearGoals() {
    _goals = [];
    _error = null;
    notifyListeners();
  }
}
