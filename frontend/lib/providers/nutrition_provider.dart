import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omniconnect_fitness/models/diet_models.dart';
import 'package:omniconnect_fitness/services/nutrition_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Provider para gerenciar estado de nutrição (Dieta, Logbook e Hidratação)
class NutritionProvider extends ChangeNotifier {
  final NutritionService _nutritionService;

  DietLogbook? _currentLogbook;
  Diet? _activeDiet;
  int? _userTmb;
  DateTime _currentDate = DateTime.now();

  // Estados locais adicionais para Hidratação e Consistência
  int _waterToday = 0;
  int _waterGoal = 2500;
  List<double> _last7DaysCalories = List.filled(7, 0.0);
  List<bool> _last7DaysLogged = List.filled(7, false);

  // Estado de Analytics Histórico
  NutritionAnalyticsSummary? _analyticsSummary;
  bool _analyticsLoading = false;
  String? _analyticsError;

  bool _isLoading = false;
  String? _error;

  NutritionProvider({required NutritionService nutritionService})
      : _nutritionService = nutritionService;

  // Getters
  DietLogbook? get currentLogbook => _currentLogbook;
  Diet? get activeDiet => _activeDiet;
  DateTime get currentDate => _currentDate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Getters para Hidratação e Consistência
  int get waterToday => _waterToday;
  int get waterGoal => _waterGoal;
  List<double> get last7DaysCalories => _last7DaysCalories;
  List<bool> get last7DaysLogged => _last7DaysLogged;

  // Getters para Analytics Histórico
  NutritionAnalyticsSummary? get analyticsSummary => _analyticsSummary;
  bool get analyticsLoading => _analyticsLoading;
  String? get analyticsError => _analyticsError;

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
    if (_activeDiet != null && _activeDiet!.totalKcal > 0) {
      return {
        'calories': _activeDiet!.totalKcal,
        'protein': _activeDiet!.totalProtein,
        'carbs': _activeDiet!.totalCarbs,
        'fat': _activeDiet!.totalFats,
      };
    }
    
    // Usa o gasto calórico diário estimado (TDEE = TMB * 1.5) como meta padrão
    final targetKcal = _userTmb != null ? (_userTmb! * 1.5) : 2000.0;
    
    return {
      'calories': targetKcal,
      'protein': targetKcal * 0.25 / 4, // Exemplo genérico
      'carbs': targetKcal * 0.50 / 4,
      'fat': targetKcal * 0.25 / 9,
    };
  }

  /// Carrega os dados do dia (Diário, Dieta, Água e Consistência)
  Future<void> loadTodayData() async {
    try {
      _setLoading(true);
      _error = null;

      // Chama as requisições em paralelo
      final results = await Future.wait([
        _nutritionService.getLogbookByDate(_currentDate).then((v) => v as DietLogbook?).catchError((_) => null as DietLogbook?),
        _nutritionService.getDiets().then((v) => v as List<Diet>?).catchError((_) => <Diet>[]),
        _nutritionService.getUserTmb().catchError((_) => null as int?),
        _loadWaterForCurrentDate(),
        _loadLast7DaysLogs(),
      ]);

      _currentLogbook = results[0] as DietLogbook?;
      
      final diets = results[1] as List<Diet>?;
      if (diets != null && diets.isNotEmpty) {
        _activeDiet = diets.firstWhere((d) => d.isActive, orElse: () => diets.first);
        _waterGoal = _activeDiet!.waterTargetMl;
      } else {
        _activeDiet = null;
        _waterGoal = 2500;
      }
      
      _userTmb = results[2] as int?;

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
      
      // Recarrega o logbook do dia e recalcula consistência
      final futureResults = await Future.wait([
        _nutritionService.getLogbookByDate(dto.logDate ?? DateTime.now()),
        _loadLast7DaysLogs(),
      ]);
      _currentLogbook = futureResults[0] as DietLogbook?;
      
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
      
      // Recarrega o logbook e a consistência
      final futureResults = await Future.wait([
        _nutritionService.getLogbookByDate(date),
        _loadLast7DaysLogs(),
      ]);
      _currentLogbook = futureResults[0] as DietLogbook?;
      
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

  /// Cria um novo alimento personalizado no servidor
  Future<CustomFood> createCustomFood({
    required String name,
    String? category,
    required double energyKcal,
    required double proteinG,
    required double carbohydrateG,
    required double lipidG,
    double fiberG = 0.0,
  }) async {
    try {
      _setLoading(true);
      _error = null;
      final food = await _nutritionService.createCustomFood(
        name: name,
        category: category,
        energyKcal: energyKcal,
        proteinG: proteinG,
        carbohydrateG: carbohydrateG,
        lipidG: lipidG,
        fiberG: fiberG,
      );
      return food;
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao criar alimento: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Analytics Histórico (Backend Aggregation)
  // ---------------------------------------------------------------------------

  /// Carrega o sumário histórico de nutrição para um período.
  /// [days]: número de dias retroativos (ex: 7, 30, 60, 90).
  Future<void> loadAnalyticsSummary({int days = 30}) async {
    _analyticsLoading = true;
    _analyticsError = null;
    notifyListeners();
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days - 1));
      _analyticsSummary = await _nutritionService.getAnalyticsSummary(
        startDate: startDate,
        endDate: endDate,
      );
    } on NetworkException catch (e) {
      _analyticsError = 'Erro de conexão: ${e.message}';
    } catch (e) {
      _analyticsError = 'Erro ao carregar histórico: ${e.toString()}';
    } finally {
      _analyticsLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Hidratação (Persistência Local SharedPreferences)
  // ---------------------------------------------------------------------------

  String _getWaterKey(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'water_log_${y}_${m}_${d}';
  }

  Future<void> _loadWaterForCurrentDate() async {
    try {
      final key = _getWaterKey(_currentDate);
      final prefs = await SharedPreferences.getInstance();
      _waterToday = prefs.getInt(key) ?? 0;
    } catch (_) {
      _waterToday = 0;
    }
  }

  Future<void> addWater(int ml) async {
    try {
      _waterToday = (_waterToday + ml).clamp(0, 10000);
      final key = _getWaterKey(_currentDate);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, _waterToday);
      notifyListeners();
    } catch (_) {
      // Falha silenciosa local
    }
  }

  Future<void> resetWater() async {
    try {
      _waterToday = 0;
      final key = _getWaterKey(_currentDate);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, 0);
      notifyListeners();
    } catch (_) {
      // Falha silenciosa local
    }
  }

  // ---------------------------------------------------------------------------
  // Consistência Semanal (Streaks)
  // ---------------------------------------------------------------------------

  Future<void> _loadLast7DaysLogs() async {
    try {
      final futures = <Future<DietLogbook?>>[];
      for (int i = 6; i >= 0; i--) {
        final date = _currentDate.subtract(Duration(days: i));
        futures.add(
          _nutritionService.getLogbookByDate(date)
              .then((v) => v as DietLogbook?)
              .catchError((_) => null)
        );
      }
      
      final logs = await Future.wait(futures);
      _last7DaysCalories = logs.map((log) => log?.totalKcal ?? 0.0).toList();
      _last7DaysLogged = logs.map((log) => log != null && log.entries.isNotEmpty).toList();
    } catch (_) {
      _last7DaysCalories = List.filled(7, 0.0);
      _last7DaysLogged = List.filled(7, false);
    }
  }

  // ---------------------------------------------------------------------------
  // Coach Nutricional de Inteligência Artificial (Modelo Base)
  // ---------------------------------------------------------------------------

  /// Retorna um feedback inteligente em tempo real baseado no consumo do dia.
  /// Contém um template estruturado com orientações claras sobre como a equipe
  /// do cliente pode futuramente integrar com o backend alimentado por LLM.
  Map<String, String> getAICoachFeedback() {
    final caloriesConsumed = _currentLogbook?.totalKcal ?? 0.0;
    final caloriesTarget = dailyTargets['calories'] ?? 2000.0;
    
    final proteinConsumed = _currentLogbook?.totalProtein ?? 0.0;
    final proteinTarget = dailyTargets['protein'] ?? 120.0;

    String title = "Dica do OmniAI Coach 💡";
    String advice = "Registrar seus alimentos e manter a hidratação constante são os passos mais importantes para a consistência diária. Continue assim!";
    String type = "info"; // info, warning, success, alert

    // Lógica inteligente local por regras para simulação perfeita do comportamento
    if (caloriesConsumed == 0) {
      title = "Inicie seu diário alimentar 🍳";
      advice = "Seu diário para hoje está vazio. Comece adicionando sua refeição para receber insights automáticos de IA sobre seu progresso!";
      type = "info";
    } else if (_waterToday < _waterGoal * 0.5) {
      title = "Atenção com a hidratação! 💧";
      advice = "Seu consumo de água está abaixo de 50% da meta recomendada. Beber água é essencial para manter o metabolismo ativo, otimizar a digestão e evitar retenção líquida!";
      type = "warning";
    } else if (proteinConsumed < proteinTarget * 0.7) {
      title = "Foco nas proteínas 💪";
      advice = "Você consumiu apenas ${proteinConsumed.toStringAsFixed(0)}g de proteína hoje. Para manter a massa magra e saciedade, tente incluir uma fonte de proteína magra na próxima refeição!";
      type = "alert";
    } else if (caloriesConsumed > caloriesTarget * 1.1) {
      title = "Limite calórico atingido ⚠️";
      advice = "Você ultrapassou a sua meta calórica planejada em ${(caloriesConsumed - caloriesTarget).toStringAsFixed(0)} kcal. Opte por alimentos com menor densidade calórica e ricos em fibras nas próximas horas.";
      type = "warning";
    } else if (proteinConsumed >= proteinTarget && caloriesConsumed <= caloriesTarget) {
      title = "Metas perfeitamente batidas! 🏆";
      advice = "Excelente equilíbrio de nutrientes! Você bateu a sua meta diária de proteínas permanecendo dentro do orçamento de calorias. Excelente trabalho!";
      type = "success";
    }

    return {
      'title': title,
      'advice': advice,
      'type': type,
      /* 
         --- ORIENTAÇÃO DE INTEGRAÇÃO COM BACKEND ---
         Para plugar com a IA real conectada ao modelo de linguagem do backend:
         
         1. Crie uma rota no backend (ex: `GET /api/v1/nutrition/coach-insight?date=...`)
         2. No endpoint do backend, envie o diário alimentar do dia (alimentos, quantidades e macros totais)
            como contexto do Prompt para o LLM.
         3. Chame esse endpoint aqui via HTTP utilizando o `_nutritionService` ou `_apiClient`.
         4. Atualize um estado local `_aiFeedbackFromServer` e chame `notifyListeners()`.
         
         Exemplo de código futuro:
         
         try {
           final response = await _nutritionService.getAICoachInsight(currentDate);
           _aiFeedback = response; // { "title": "...", "advice": "...", "type": "..." }
           notifyListeners();
         } catch(e) {
           // Fallback para a regra local
         }
      */
    };
  }

  // ---------------------------------------------------------------------------
  // Utilidades do Estado
  // ---------------------------------------------------------------------------

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void changeDate(DateTime newDate) {
    _currentDate = newDate;
    loadTodayData();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

