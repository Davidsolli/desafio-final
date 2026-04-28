import 'package:omniconnect_fitness/services/api_client.dart';

/// Modelo de resposta de meta
class GoalResponse {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String status;
  final double targetValue;
  final double currentValue;
  final String unit;
  final DateTime deadline;
  final DateTime createdAt;
  final DateTime? updatedAt;

  GoalResponse({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.status,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.deadline,
    required this.createdAt,
    this.updatedAt,
  });

  factory GoalResponse.fromJson(Map<String, dynamic> json) {
    return GoalResponse(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      targetValue: (json['target_value'] as num).toDouble(),
      currentValue: (json['current_value'] as num).toDouble(),
      unit: json['unit'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  double get progressPercentage => (currentValue / targetValue * 100).clamp(0, 100);

  bool get isCompleted => status == 'completed';

  bool get isExpired => deadline.isBefore(DateTime.now());
}

/// Modelo para criar/atualizar meta
class CreateGoalDTO {
  final String title;
  final String description;
  final double targetValue;
  final String unit;
  final DateTime deadline;

  CreateGoalDTO({
    required this.title,
    required this.description,
    required this.targetValue,
    required this.unit,
    required this.deadline,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'target_value': targetValue,
    'unit': unit,
    'deadline': deadline.toIso8601String(),
  };
}

/// Serviço de metas
class GoalService {
  final ApiClient _apiClient;

  GoalService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Lista todas as metas do usuário
  Future<List<GoalResponse>> getGoals({
    String? status,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (status case final s?) 'status': s,
      };

      final response = await _apiClient.get<List<GoalResponse>>(
        '/goals',
        queryParameters: queryParameters,
        fromJson: (data) {
          if (data is List) {
            return data
                .whereType<Map<String, dynamic>>()
                .map((item) => GoalResponse.fromJson(item))
                .toList();
          } else if (data is Map && data.containsKey('data')) {
            final items = data['data'] as List;
            return items
                .whereType<Map<String, dynamic>>()
                .map((item) => GoalResponse.fromJson(item))
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

  /// Busca uma meta específica
  Future<GoalResponse> getGoal(String goalId) async {
    try {
      final response = await _apiClient.get<GoalResponse>(
        '/goals/$goalId',
        fromJson: (data) => GoalResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Cria uma nova meta
  Future<GoalResponse> createGoal(CreateGoalDTO dto) async {
    try {
      final response = await _apiClient.post<GoalResponse>(
        '/goals',
        body: dto.toJson(),
        fromJson: (data) => GoalResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Atualiza progresso da meta
  Future<GoalResponse> updateGoal(String goalId, double currentValue) async {
    try {
      final response = await _apiClient.put<GoalResponse>(
        '/goals/$goalId',
        body: {'current_value': currentValue},
        fromJson: (data) => GoalResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Deleta uma meta
  Future<void> deleteGoal(String goalId) async {
    try {
      await _apiClient.delete<void>(
        '/goals/$goalId',
        fromJson: (_) {},
      );
    } catch (e) {
      rethrow;
    }
  }
}
