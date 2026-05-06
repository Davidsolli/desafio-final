import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/goal_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Provider para gerenciar estado de metas
class GoalProvider extends ChangeNotifier {
  final GoalService _goalService;

  List<GoalResponse> _goals = [];
  int _total = 0;
  int _currentPage = 1;
  String? _currentStatus;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  GoalProvider({required GoalService goalService}) : _goalService = goalService;

  List<GoalResponse> get goals => _goals;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasGoals => _goals.isNotEmpty;
  bool get hasMore => _goals.length < _total;

  /// Carrega a primeira página de metas
  Future<void> loadGoals({String? status}) async {
    try {
      _setLoading(true);
      _error = null;
      _currentStatus = status;

      final page = await _goalService.getGoals(status: status, page: 1);
      _goals = page.goals;
      _total = page.total;
      _currentPage = 1;
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

  /// Carrega a próxima página e adiciona à lista
  Future<void> loadMoreGoals() async {
    if (!hasMore || _isLoadingMore) return;
    try {
      _isLoadingMore = true;
      notifyListeners();

      final nextPage = _currentPage + 1;
      final page = await _goalService.getGoals(status: _currentStatus, page: nextPage);
      _goals = [..._goals, ...page.goals];
      _currentPage = nextPage;
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao carregar mais: ${e.toString()}';
      notifyListeners();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Cria uma nova meta
  Future<void> createGoal(CreateGoalDTO dto) async {
    try {
      _setLoading(true);
      _error = null;

      final newGoal = await _goalService.createGoal(dto);
      // Novas metas sempre chegam como 'active'; só insere na lista se o filtro atual corresponde
      if (_currentStatus == null || _currentStatus == 'active') {
        _goals.insert(0, newGoal);
        _total += 1;
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
      _total = (_total - 1).clamp(0, _total);
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

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearGoals() {
    _goals = [];
    _total = 0;
    _currentPage = 1;
    _error = null;
    notifyListeners();
  }
}
