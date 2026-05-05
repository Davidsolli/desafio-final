import 'package:omniconnect_fitness/services/api_client.dart';
import 'package:omniconnect_fitness/models/diet_models.dart';

/// Serviço de Nutrição (Dietas e Logbook Alimentar)
class NutritionService {
  final ApiClient _apiClient;

  NutritionService({required ApiClient apiClient}) : _apiClient = apiClient;

  // ---------------------------------------------------------------------------
  // Catálogo de Alimentos (TACO + Personalizados)
  // ---------------------------------------------------------------------------

  /// Busca alimentos na tabela TACO e alimentos personalizados do usuário
  Future<PaginatedFoodCatalogDTO> searchFoodCatalog(String query) async {
    try {
      final response = await _apiClient.get<PaginatedFoodCatalogDTO>(
        '/food-catalog',
        queryParameters: {'search': query},
        fromJson: (data) => PaginatedFoodCatalogDTO.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Diário Alimentar (Logbook)
  // ---------------------------------------------------------------------------

  /// Busca o diário alimentar de uma data específica
  Future<DietLogbook> getLogbookByDate(DateTime date) async {
    try {
      final dateString = date.toIso8601String().split('T')[0];
      final response = await _apiClient.get<DietLogbook>(
        '/diet-logbook/$dateString',
        fromJson: (data) => DietLogbook.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Adiciona uma entrada no diário alimentar (consumo de alimento)
  Future<DietLogbookEntry> addLogbookEntry(CreateDietLogbookEntryDTO dto) async {
    try {
      final response = await _apiClient.post<DietLogbookEntry>(
        '/diet-logbook',
        body: dto.toJson(),
        fromJson: (data) => DietLogbookEntry.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Deleta uma entrada do diário alimentar
  Future<void> deleteLogbookEntry(String entryId) async {
    try {
      await _apiClient.delete<void>(
        '/diet-logbook/entries/$entryId',
        fromJson: (_) {},
      );
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Dietas (Plano Alimentar Prescrito)
  // ---------------------------------------------------------------------------

  /// Lista as dietas do usuário (geralmente uma ativa)
  Future<List<Diet>> getMyDiets() async {
    try {
      final response = await _apiClient.get<PaginatedDietsDTO>(
        '/diets',
        queryParameters: {'limit': 10},
        fromJson: (data) => PaginatedDietsDTO.fromJson(data as Map<String, dynamic>),
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}

