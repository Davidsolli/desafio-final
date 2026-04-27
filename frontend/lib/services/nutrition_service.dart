import 'package:omniconnect_fitness/services/api_client.dart';

/// Modelo de alimento
class Food {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  Food({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'] as String,
      name: json['name'] as String,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
    );
  }
}

/// Modelo de refeição registrada
class MealResponse {
  final String id;
  final String userId;
  final String mealType; // breakfast, lunch, dinner, snack
  final DateTime mealDate;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final List<Food> foods;
  final String? notes;
  final DateTime createdAt;

  MealResponse({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.mealDate,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.foods,
    this.notes,
    required this.createdAt,
  });

  factory MealResponse.fromJson(Map<String, dynamic> json) {
    return MealResponse(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mealType: json['meal_type'] as String,
      mealDate: DateTime.parse(json['meal_date'] as String),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      foods: (json['foods'] as List<dynamic>?)
          ?.map((e) => Food.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// DTO para criar/atualizar refeição
class CreateMealDTO {
  final String mealType;
  final DateTime mealDate;
  final List<Map<String, dynamic>> foods;
  final String? notes;

  CreateMealDTO({
    required this.mealType,
    required this.mealDate,
    required this.foods,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'meal_type': mealType,
    'meal_date': mealDate.toIso8601String(),
    'foods': foods,
    if (notes != null) 'notes': notes,
  };
}

/// Serviço de nutrição
class NutritionService {
  final ApiClient _apiClient;

  NutritionService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Lista todas as refeições do usuário
  Future<List<MealResponse>> getMeals({
    DateTime? date,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (date != null) 'date': date.toIso8601String().split('T')[0],
      };

      final response = await _apiClient.get<List<MealResponse>>(
        '/nutrition/meals',
        queryParameters: queryParameters,
        fromJson: (data) {
          if (data is List) {
            return data
                .whereType<Map<String, dynamic>>()
                .map((item) => MealResponse.fromJson(item))
                .toList();
          } else if (data is Map && data.containsKey('data')) {
            final items = data['data'] as List;
            return items
                .whereType<Map<String, dynamic>>()
                .map((item) => MealResponse.fromJson(item))
                .toList();
          }
          return [];
        },
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Cria uma nova refeição
  Future<MealResponse> createMeal(CreateMealDTO dto) async {
    try {
      final response = await _apiClient.post<MealResponse>(
        '/nutrition/meals',
        body: dto.toJson(),
        fromJson: (data) => MealResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Atualiza uma refeição
  Future<MealResponse> updateMeal(String mealId, CreateMealDTO dto) async {
    try {
      final response = await _apiClient.put<MealResponse>(
        '/nutrition/meals/$mealId',
        body: dto.toJson(),
        fromJson: (data) => MealResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Deleta uma refeição
  Future<void> deleteMeal(String mealId) async {
    try {
      await _apiClient.delete<void>(
        '/nutrition/meals/$mealId',
        fromJson: (_) {},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Busca alimentos disponíveis
  Future<List<Food>> searchFoods(String query) async {
    try {
      final response = await _apiClient.get<List<Food>>(
        '/nutrition/foods/search',
        queryParameters: {'q': query},
        fromJson: (data) {
          if (data is List) {
            return data
                .whereType<Map<String, dynamic>>()
                .map((item) => Food.fromJson(item))
                .toList();
          }
          return [];
        },
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
