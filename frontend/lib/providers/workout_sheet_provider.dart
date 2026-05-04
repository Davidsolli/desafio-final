import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/models/workout_sheet_model.dart';
import 'package:omniconnect_fitness/services/workout_sheet_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Provider para gerenciar estado de fichas de treino.
///
/// Segue o padrão estabelecido por GoalProvider:
/// - Expõe lista de fichas, estado de loading e erro
/// - Notifica listeners em cada mudança de estado
/// - Trata exceções de rede, API e conflito (RN-01)
class WorkoutSheetProvider extends ChangeNotifier {
  final WorkoutSheetService _service;

  List<WorkoutSheetListItem> _sheets = [];
  WorkoutSheetResponse? _selectedSheet;
  List<ExerciseCatalogItem> _catalogItems = [];
  int _totalSheets = 0;
  int _currentPage = 1;
  bool _isLoading = false;
  String? _error;

  WorkoutSheetProvider({required WorkoutSheetService workoutSheetService})
      : _service = workoutSheetService;

  // Getters
  List<WorkoutSheetListItem> get sheets => _sheets;
  WorkoutSheetResponse? get selectedSheet => _selectedSheet;
  List<ExerciseCatalogItem> get catalogItems => _catalogItems;
  int get totalSheets => _totalSheets;
  int get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasSheets => _sheets.isNotEmpty;

  /// Carrega fichas de treino com paginação e filtros.
  Future<void> loadSheets({
    String? userId,
    int? dayOfWeek,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final result = await _service.listWorkoutSheets(
        userId: userId,
        dayOfWeek: dayOfWeek,
        page: page,
        limit: limit,
      );

      _sheets = result.data;
      _totalSheets = result.total;
      _currentPage = result.page;
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
      _error = 'Erro ao carregar fichas: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega detalhes de uma ficha específica (com exercícios).
  Future<void> loadSheetDetail(String sheetId) async {
    try {
      _setLoading(true);
      _error = null;

      _selectedSheet = await _service.getWorkoutSheet(sheetId);
      notifyListeners();
    } on NotFoundException catch (e) {
      _error = 'Ficha não encontrada: ${e.message}';
      notifyListeners();
      rethrow;
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar ficha: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Cria uma nova ficha de treino.
  ///
  /// Retorna a ficha criada. Trata RN-01 (conflito de dia da semana).
  Future<WorkoutSheetResponse> createSheet(CreateWorkoutSheetDTO dto) async {
    try {
      _setLoading(true);
      _error = null;

      final newSheet = await _service.createWorkoutSheet(dto);
      // Recarrega a lista para refletir a nova ficha
      await _refreshSheets();
      return newSheet;
    } on WorkoutSheetConflictException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao criar ficha: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza uma ficha de treino.
  ///
  /// Trata RN-01 (conflito de dia da semana).
  Future<WorkoutSheetResponse> updateSheet(
    String sheetId,
    UpdateWorkoutSheetDTO dto,
  ) async {
    try {
      _setLoading(true);
      _error = null;

      final updated = await _service.updateWorkoutSheet(sheetId, dto);
      _selectedSheet = updated;
      await _refreshSheets();
      return updated;
    } on WorkoutSheetConflictException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao atualizar ficha: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Deleta uma ficha de treino (soft delete).
  Future<void> deleteSheet(String sheetId) async {
    try {
      _setLoading(true);
      _error = null;

      await _service.deleteWorkoutSheet(sheetId);
      _sheets.removeWhere((s) => s.id == sheetId);
      if (_selectedSheet?.id == sheetId) {
        _selectedSheet = null;
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
      _error = 'Erro ao deletar ficha: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Duplica uma ficha existente.
  ///
  /// Trata RN-01 (conflito de dia da semana).
  Future<WorkoutSheetResponse> duplicateSheet(
    String sheetId,
    DuplicateWorkoutSheetDTO dto,
  ) async {
    try {
      _setLoading(true);
      _error = null;

      final duplicated = await _service.duplicateWorkoutSheet(sheetId, dto);
      await _refreshSheets();
      return duplicated;
    } on WorkoutSheetConflictException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao duplicar ficha: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Busca exercícios no catálogo.
  Future<void> searchCatalog({
    String? search,
    String? muscleGroup,
    String? equipment,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final result = await _service.searchExerciseCatalog(
        search: search,
        muscleGroup: muscleGroup,
        equipment: equipment,
        page: page,
        limit: limit,
      );

      _catalogItems = result.data;
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
      _error = 'Erro ao buscar catálogo: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Recarrega a lista de fichas mantendo filtros/paginação atuais.
  Future<void> _refreshSheets() async {
    try {
      final result = await _service.listWorkoutSheets(page: _currentPage);
      _sheets = result.data;
      _totalSheets = result.total;
      notifyListeners();
    } catch (_) {
      // Falha silenciosa no refresh — dados em cache permanecem
    }
  }

  /// Define o estado de carregamento.
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Limpa a mensagem de erro.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Limpa todos os dados.
  void clearAll() {
    _sheets = [];
    _selectedSheet = null;
    _catalogItems = [];
    _totalSheets = 0;
    _currentPage = 1;
    _error = null;
    notifyListeners();
  }
}
