import 'package:omniconnect_fitness/services/api_client.dart';
import 'package:omniconnect_fitness/models/workout_sheet_model.dart';

/// Exceção específica para conflito de dia da semana (RN-01).
///
/// Lançada quando o backend retorna 409 Conflict ao tentar criar/atualizar
/// uma ficha para um dia que o aluno já possui ficha ativa.
class WorkoutSheetConflictException implements Exception {
  final String message;
  WorkoutSheetConflictException(this.message);

  @override
  String toString() => 'WorkoutSheetConflictException: $message';
}

/// Serviço de Fichas de Treino.
///
/// Consome os endpoints do WorkoutSheetController (backend):
/// - GET    /workout-sheets           → Listar fichas
/// - POST   /workout-sheets           → Criar ficha
/// - GET    /workout-sheets/{id}      → Ver detalhes
/// - PUT    /workout-sheets/{id}      → Atualizar ficha
/// - DELETE /workout-sheets/{id}      → Soft delete
/// - POST   /workout-sheets/{id}/duplicate → Duplicar ficha
/// - GET    /exercise-catalog         → Buscar catálogo
class WorkoutSheetService {
  final ApiClient _apiClient;

  WorkoutSheetService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Lista fichas de treino com paginação e filtros.
  ///
  /// [userId] — Filtrar por aluno (admin/personal).
  /// [dayOfWeek] — Filtrar por dia da semana (0=seg…6=dom).
  /// [page] — Número da página (a partir de 1).
  /// [limit] — Itens por página (máx. 100).
  Future<PaginatedWorkoutSheets> listWorkoutSheets({
    String? userId,
    int? dayOfWeek,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (userId != null) 'user_id': userId,
        if (dayOfWeek != null) 'day_of_week': dayOfWeek.toString(),
      };

      final response = await _apiClient.get<PaginatedWorkoutSheets>(
        '/workout-sheets',
        queryParameters: queryParams,
        fromJson: (data) =>
            PaginatedWorkoutSheets.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Cria uma nova ficha de treino.
  ///
  /// Trata o erro 409 (RN-01: conflito de dia da semana) lançando
  /// [WorkoutSheetConflictException].
  Future<WorkoutSheetResponse> createWorkoutSheet(
      CreateWorkoutSheetDTO dto) async {
    try {
      final response = await _apiClient.post<WorkoutSheetResponse>(
        '/workout-sheets',
        body: dto.toJson(),
        fromJson: (data) =>
            WorkoutSheetResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw WorkoutSheetConflictException(e.message);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Busca uma ficha de treino pelo ID (com exercícios completos).
  Future<WorkoutSheetResponse> getWorkoutSheet(String sheetId) async {
    try {
      final response = await _apiClient.get<WorkoutSheetResponse>(
        '/workout-sheets/$sheetId',
        fromJson: (data) =>
            WorkoutSheetResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Atualiza uma ficha de treino.
  ///
  /// Trata o erro 409 (RN-01: conflito de dia da semana) lançando
  /// [WorkoutSheetConflictException].
  Future<WorkoutSheetResponse> updateWorkoutSheet(
    String sheetId,
    UpdateWorkoutSheetDTO dto,
  ) async {
    try {
      final response = await _apiClient.put<WorkoutSheetResponse>(
        '/workout-sheets/$sheetId',
        body: dto.toJson(),
        fromJson: (data) =>
            WorkoutSheetResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw WorkoutSheetConflictException(e.message);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Soft delete de uma ficha de treino.
  Future<void> deleteWorkoutSheet(String sheetId) async {
    try {
      await _apiClient.delete<void>(
        '/workout-sheets/$sheetId',
        fromJson: (_) {},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Duplica uma ficha existente.
  ///
  /// Trata o erro 409 (RN-01: conflito de dia da semana) lançando
  /// [WorkoutSheetConflictException].
  Future<WorkoutSheetResponse> duplicateWorkoutSheet(
    String sheetId,
    DuplicateWorkoutSheetDTO dto,
  ) async {
    try {
      final response = await _apiClient.post<WorkoutSheetResponse>(
        '/workout-sheets/$sheetId/duplicate',
        body: dto.toJson(),
        fromJson: (data) =>
            WorkoutSheetResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw WorkoutSheetConflictException(e.message);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Busca exercícios no catálogo (para autocompletar).
  ///
  /// [search] — Busca por nome (parcial, case-insensitive).
  /// [muscleGroup] — Filtrar por grupo muscular mapeado.
  /// [page] — Número da página.
  /// [limit] — Itens por página.
  Future<PaginatedCatalog> searchExerciseCatalog({
    String? search,
    String? muscleGroup,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (muscleGroup != null) 'muscle_group': muscleGroup,
      };

      final response = await _apiClient.get<PaginatedCatalog>(
        '/exercise-catalog',
        queryParameters: queryParams,
        fromJson: (data) =>
            PaginatedCatalog.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
