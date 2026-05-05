import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/models/diet_models.dart';
import 'package:omniconnect_fitness/services/nutrition_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Provider para gerenciar estado de nutrição (Dieta e Logbook)
class NutritionProvider extends ChangeNotifier {
  final NutritionService _nutritionService;

  DietLogbook? _currentLogbook;
  Diet? _activeDiet;

  bool _isLoading = false;
  String? _error;

  NutritionProvider({required NutritionService nutritionService})
      : _nutritionService = nutritionService;

  // Getters
  DietLogbook? get currentLogbook => _currentLogbook;
  Diet? get activeDiet => _activeDiet;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Retorna as entradas agrupadas por meal_name para facilitar a listagem
  Map<String, List<DietLogbookEntry>> get entriesByMeal {
    final map = <String, List<DietLogbookEntry>>{};
    if (_currentLogbook == null) return map;

    for (var entry in _currentLogbook!.entries) {
      if (!map.containsKey(entry.mealName)) {
        map[entry.mealName] = [];
      }
      map[entry.mealName]!.add(entry);
    }
    return map;
  }

  /// Calcula a meta calórica e macros com base na dieta ativa.
  /// Se não tiver dieta, retorna uma meta genérica de 2000kcal.
  Map<String, double> get dailyTargets {
    if (_activeDiet != null) {
      return {
        'calories': _activeDiet!.totalKcal,
        'protein': _activeDiet!.totalProtein,
        'carbs': _activeDiet!.totalCarbs,
        'fat': _activeDiet!.totalFats,
      };
    }
    return {
      'calories': 2000.0,
      'protein': 150.0,
      'carbs': 200.0,
      'fat': 66.0,
    };
  }

  /// Carrega os dados do dia (Diário e Dieta)
  Future<void> loadTodayData() async {
    try {
      _setLoading(true);
      _error = null;

      // Chama as duas requisições em paralelo
      final results = await Future.wait([
        _nutritionService.getLogbookByDate(DateTime.now()).then((v) => v as DietLogbook?).catchError((_) => null as DietLogbook?),
        _nutritionService.getMyDiets().then((v) => v as List<Diet>?).catchError((_) => <Diet>[]),
      ]);

      _currentLogbook = results[0] as DietLogbook?;
      
      final diets = results[1] as List<Diet>?;
      if (diets != null && diets.isNotEmpty) {
        // Pega a dieta ativa, ou a primeira se não tiver uma flag 'isActive'
        _activeDiet = diets.firstWhere((d) => d.isActive, orElse: () => diets.first);
      } else {
        _activeDiet = null;
      }

      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao carregar dados nutricionais: ${e.toString()}';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Adiciona uma entrada no diário alimentar
  Future<void> addLogbookEntry(CreateDietLogbookEntryDTO dto) async {
    try {
      _setLoading(true);
      _error = null;

      await _nutritionService.addLogbookEntry(dto);
      
      // Recarrega o logbook do dia para pegar os totais calculados no backend
      _currentLogbook = await _nutritionService.getLogbookByDate(dto.logDate ?? DateTime.now());
      
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
      _error = 'Erro ao adicionar alimento: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Deleta uma entrada do diário alimentar
  Future<void> deleteLogbookEntry(String entryId, DateTime date) async {
    try {
      _setLoading(true);
      _error = null;

      await _nutritionService.deleteLogbookEntry(entryId);
      
      // Recarrega o logbook
      _currentLogbook = await _nutritionService.getLogbookByDate(date);
      
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
      _error = 'Erro ao deletar alimento: ${e.toString()}';
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
}

