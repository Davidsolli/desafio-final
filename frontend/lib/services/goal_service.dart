import 'package:omniconnect_fitness/services/api_client.dart';

/// Modelo de resposta de meta
class GoalResponse {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String status;
  final String category;
  final double targetValue;
  final double currentValue;
  final String unit;
  final DateTime targetDate;
  final double progressPercentage;
  final int daysRemaining;
  final DateTime createdAt;

  GoalResponse({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.status,
    required this.category,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.targetDate,
    required this.progressPercentage,
    required this.daysRemaining,
    required this.createdAt,
  });

  factory GoalResponse.fromJson(Map<String, dynamic> json) {
    return GoalResponse(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      category: json['category'] as String? ?? 'general',
      targetValue: (json['target_value'] as num).toDouble(),
      currentValue: (json['current_value'] as num).toDouble(),
      unit: json['unit'] as String,
      targetDate: DateTime.parse(json['target_date'] as String),
      progressPercentage: (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isCompleted => status == 'completed';

  bool get isExpired => status == 'failed' || (targetDate.isBefore(DateTime.now()) && !isCompleted);
}

/// Entrada de histórico de progresso
class GoalProgressEntry {
  final String id;
  final double currentValue;
  final DateTime recordedAt;
  final String? notes;

  GoalProgressEntry({
    required this.id,
    required this.currentValue,
    required this.recordedAt,
    this.notes,
  });

  factory GoalProgressEntry.fromJson(Map<String, dynamic> json) {
    return GoalProgressEntry(
      id: json['id'] as String,
      currentValue: (json['current_value'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}

/// Detalhe completo de uma meta (com histórico)
class GoalDetail extends GoalResponse {
  final List<GoalProgressEntry> progressEntries;

  GoalDetail({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    required super.status,
    required super.category,
    required super.targetValue,
    required super.currentValue,
    required super.unit,
    required super.targetDate,
    required super.progressPercentage,
    required super.daysRemaining,
    required super.createdAt,
    required this.progressEntries,
  });

  factory GoalDetail.fromJson(Map<String, dynamic> json) {
    final entries = (json['progress_entries'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => GoalProgressEntry.fromJson(e))
        .toList();
    return GoalDetail(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      category: json['category'] as String? ?? 'general',
      targetValue: (json['target_value'] as num).toDouble(),
      currentValue: (json['current_value'] as num).toDouble(),
      unit: json['unit'] as String,
      targetDate: DateTime.parse(json['target_date'] as String),
      progressPercentage: (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      progressEntries: entries,
    );
  }
}

/// Resultado paginado de metas
class GoalPage {
  final int total;
  final int page;
  final List<GoalResponse> goals;

  GoalPage({required this.total, required this.page, required this.goals});
}

/// Modelo para criar meta
class CreateGoalDTO {
  final String userId;
  final String title;
  final String? description;
  final String category;
  final double currentValue;
  final double targetValue;
  final String unit;
  final DateTime targetDate;

  CreateGoalDTO({
    required this.userId,
    required this.title,
    this.description,
    required this.category,
    required this.currentValue,
    required this.targetValue,
    required this.unit,
    required this.targetDate,
  });

  Map<String, dynamic> toJson() {
    final y = targetDate.year.toString().padLeft(4, '0');
    final m = targetDate.month.toString().padLeft(2, '0');
    final d = targetDate.day.toString().padLeft(2, '0');
    return {
      'user_id': userId,
      'title': title,
      if (description != null && description!.isNotEmpty) 'description': description,
      'category': category,
      'current_value': currentValue,
      'target_value': targetValue,
      'unit': unit,
      'target_date': '$y-$m-$d',
    };
  }
}

/// Serviço de metas
class GoalService {
  final ApiClient _apiClient;

  GoalService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Lista metas com suporte a paginação
  Future<GoalPage> getGoals({String? status, int page = 1, int limit = 10}) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
    };

    final response = await _apiClient.get<GoalPage>(
      '/goals',
      queryParameters: queryParameters,
      fromJson: (data) {
        if (data is Map && data.containsKey('data')) {
          final items = (data['data'] as List)
              .whereType<Map<String, dynamic>>()
              .map((item) => GoalResponse.fromJson(item))
              .toList();
          return GoalPage(
            total: data['total'] as int? ?? items.length,
            page: data['page'] as int? ?? page,
            goals: items,
          );
        }
        if (data is List) {
          final items = data
              .whereType<Map<String, dynamic>>()
              .map((item) => GoalResponse.fromJson(item))
              .toList();
          return GoalPage(total: items.length, page: 1, goals: items);
        }
        return GoalPage(total: 0, page: 1, goals: []);
      },
    );
    return response;
  }

  /// Busca detalhe completo de uma meta (com histórico)
  Future<GoalDetail> getGoalDetail(String goalId) async {
    final response = await _apiClient.get<GoalDetail>(
      '/goals/$goalId',
      fromJson: (data) => GoalDetail.fromJson(data as Map<String, dynamic>),
    );
    return response;
  }

  /// Cria uma nova meta
  Future<GoalResponse> createGoal(CreateGoalDTO dto) async {
    final response = await _apiClient.post<GoalResponse>(
      '/goals',
      body: dto.toJson(),
      fromJson: (data) => GoalResponse.fromJson(data as Map<String, dynamic>),
    );
    return response;
  }

  /// Atualiza progresso da meta
  Future<GoalResponse> updateGoal(String goalId, double currentValue) async {
    final response = await _apiClient.put<GoalResponse>(
      '/goals/$goalId',
      body: {'current_value': currentValue},
      fromJson: (data) => GoalResponse.fromJson(data as Map<String, dynamic>),
    );
    return response;
  }

  /// Deleta uma meta
  Future<void> deleteGoal(String goalId) async {
    await _apiClient.delete<void>(
      '/goals/$goalId',
      fromJson: (_) {},
    );
  }
}
