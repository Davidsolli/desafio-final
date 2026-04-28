import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/nutrition_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Provider para gerenciar estado de nutrição
class NutritionProvider extends ChangeNotifier {
  final NutritionService _nutritionService;

  List<MealResponse> _meals = [];
  bool _isLoading = false;
  String? _error;

  NutritionProvider({required NutritionService nutritionService})
      : _nutritionService = nutritionService;

  // Getters
  List<MealResponse> get meals => _meals;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMeals => _meals.isNotEmpty;

  /// Calcula totais do dia
  Map<String, double> get dailyTotals {
    return {
      'calories': _meals.fold<double>(0, (sum, m) => sum + m.calories),
      'protein': _meals.fold<double>(0, (sum, m) => sum + m.protein),
      'carbs': _meals.fold<double>(0, (sum, m) => sum + m.carbs),
      'fat': _meals.fold<double>(0, (sum, m) => sum + m.fat),
    };
  }

  /// Carrega todas as refeições do dia
  Future<void> loadMeals({DateTime? date, int limit = 10, int offset = 0}) async {
    try {
      _setLoading(true);
      _error = null;

      _meals = await _nutritionService.getMeals(
        date: date ?? DateTime.now(),
        limit: limit,
        offset: offset,
      );
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
      _error = 'Erro ao carregar refeições: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Cria uma nova refeição
  Future<void> createMeal(CreateMealDTO dto) async {
    try {
      _setLoading(true);
      _error = null;

      final newMeal = await _nutritionService.createMeal(dto);
      _meals.insert(0, newMeal);
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
      _error = 'Erro ao criar refeição: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza uma refeição
  Future<void> updateMeal(String mealId, CreateMealDTO dto) async {
    try {
      _setLoading(true);
      _error = null;

      final updatedMeal = await _nutritionService.updateMeal(mealId, dto);

      final index = _meals.indexWhere((m) => m.id == mealId);
      if (index != -1) {
        _meals[index] = updatedMeal;
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
      _error = 'Erro ao atualizar refeição: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Deleta uma refeição
  Future<void> deleteMeal(String mealId) async {
    try {
      _setLoading(true);
      _error = null;

      await _nutritionService.deleteMeal(mealId);
      _meals.removeWhere((m) => m.id == mealId);
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
      _error = 'Erro ao deletar refeição: ${e.toString()}';
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

  /// Limpa todas as refeições
  void clearMeals() {
    _meals = [];
    _error = null;
    notifyListeners();
  }
}
