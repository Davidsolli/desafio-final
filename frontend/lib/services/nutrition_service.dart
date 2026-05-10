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
  Future<PaginatedFoodCatalogDTO> searchFoodCatalog(
    String query, {
    String? category,
    String? source,
    double? minProtein,
    double? maxCarbohydrate,
    double? maxLipid,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'search': query,
        if (category != null) 'category': category,
        if (source != null) 'source': source,
        if (minProtein != null) 'min_protein': minProtein.toString(),
        if (maxCarbohydrate != null) 'max_carbohydrate': maxCarbohydrate.toString(),
        if (maxLipid != null) 'max_lipid': maxLipid.toString(),
      };
      
      final response = await _apiClient.get<PaginatedFoodCatalogDTO>(
        '/food-catalog',
        queryParameters: queryParameters,
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

  /// Lista dietas, podendo filtrar por aluno (personal/admin).
  Future<List<Diet>> getDiets({String? userId, int limit = 10}) async {
    try {
      final queryParameters = <String, dynamic>{
        'limit': limit.toString(),
        if (userId != null) 'user_id': userId,
      };
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/diets',
        queryParameters: queryParameters,
        fromJson: (data) => data as Map<String, dynamic>,
      );

      // O endpoint de listagem retorna itens resumidos. Para exibir a aba de
      // nutrição com refeições/itens/macros completos, buscamos cada dieta
      // individualmente no endpoint de detalhe.
      final List<dynamic> items = response['data'] as List<dynamic>? ?? [];
      if (items.isEmpty) return [];

      final List<Diet> detailedDiets = [];
      for (final item in items) {
        final dietMap = item as Map<String, dynamic>;
        final dietId = dietMap['id']?.toString();
        if (dietId == null || dietId.isEmpty) continue;
        final detail = await getDietById(dietId);
        detailedDiets.add(detail);
      }
      return detailedDiets;
    } catch (e) {
      rethrow;
    }
  }

  /// Busca dieta completa (refeições/itens/macros).
  Future<Diet> getDietById(String dietId) async {
    try {
      final response = await _apiClient.get<Diet>(
        '/diets/$dietId',
        fromJson: (data) => Diet.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Atualiza dieta (nome/objetivo/refeições).
  Future<Diet> updateDiet({
    required String dietId,
    String? name,
    String? goal,
    required List<Map<String, dynamic>> meals,
  }) async {
    try {
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (goal != null) 'goal': goal,
        'meals': meals,
      };
      final response = await _apiClient.put<Diet>(
        '/diets/$dietId',
        body: body,
        fromJson: (data) => Diet.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Compatibilidade com chamadas antigas.
  Future<List<Diet>> getMyDiets() async {
    return getDiets();
  }

  /// Busca a Taxa Metabólica Basal (TMB) do usuário logado
  Future<int?> getUserTmb() async {
    try {
      final userResponse = await _apiClient.get<Map<String, dynamic>>(
        '/users/me',
        fromJson: (data) => data as Map<String, dynamic>,
      );
      final weight = (userResponse['weight'] as num?)?.toDouble();
      final height = (userResponse['height'] as num?)?.toDouble();
      final age = userResponse['age'] as int?;
      final gender = userResponse['gender'] as String?;
      
      if (weight != null && weight > 0 && height != null && height > 0 && age != null && age > 0) {
        if (gender == 'male') {
            return (88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age)).toInt();
        }
        return (447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age)).toInt();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cria um alimento personalizado para o usuário
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
      final response = await _apiClient.post<CustomFood>(
        '/custom-foods',
        body: {
          'name': name,
          if (category != null && category.trim().isNotEmpty) 'category': category,
          'energy_kcal': energyKcal,
          'protein_g': proteinG,
          'carbohydrate_g': carbohydrateG,
          'lipid_g': lipidG,
          'fiber_g': fiberG,
        },
        fromJson: (data) => CustomFood.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}

