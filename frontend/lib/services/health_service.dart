import 'package:omniconnect_fitness/services/api_client.dart';
import 'package:omniconnect_fitness/services/health_connect_service.dart';

/// DTO de resposta do endpoint de sync de saúde.
class HealthSyncResponse {
  final bool success;
  final String message;

  HealthSyncResponse({required this.success, required this.message});

  factory HealthSyncResponse.fromJson(Map<String, dynamic> json) =>
      HealthSyncResponse(
        success: json['success'] as bool? ?? true,
        message: json['message'] as String? ?? 'ok',
      );
}

/// Resumo de saúde retornado pelo GET /health/summary.
class HealthSummary {
  final double averageHeartRateBpm;
  final double activeCalories;
  final double totalCalories;
  final DateTime date;
  final bool isFromSmartwatch;
  final String smartwatchSourceName;

  HealthSummary({
    required this.averageHeartRateBpm,
    required this.activeCalories,
    required this.totalCalories,
    required this.date,
    this.isFromSmartwatch = false,
    this.smartwatchSourceName = '',
  });

  factory HealthSummary.fromJson(Map<String, dynamic> json) => HealthSummary(
        averageHeartRateBpm:
            (json['average_heart_rate_bpm'] as num?)?.toDouble() ?? 0,
        activeCalories: (json['active_calories'] as num?)?.toDouble() ?? 0,
        totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
        date: DateTime.parse(json['date'] as String),
        isFromSmartwatch: json['is_from_smartwatch'] as bool? ?? false,
        smartwatchSourceName: json['smartwatch_source_name'] as String? ?? '',
      );
}

/// Cliente HTTP para o módulo de saúde (FC + calorias).
class HealthService {
  final ApiClient _apiClient;

  HealthService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Sincroniza frequência cardíaca e calorias do dia com o backend.
  Future<HealthSyncResponse> syncHealthData({
    required List<HeartRateSample> heartRateSamples,
    required DailyCalories calories,
    required DateTime date,
  }) async {
    final body = <String, dynamic>{
      'date': _formatDate(date),
      'active_calories': calories.active,
      'total_calories': calories.total,
      'heart_rate_readings': heartRateSamples
          .map((s) => {
                'measured_at': s.measuredAt.toUtc().toIso8601String(),
                'bpm': s.bpm,
                'is_from_smartwatch': s.isFromSmartwatch,
                'source_name': s.sourceName,
              })
          .toList(),
    };

    return _apiClient.post<HealthSyncResponse>(
      '/health/sync',
      body: body,
      fromJson: (data) =>
          HealthSyncResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Busca o resumo de saúde do dia atual.
  Future<HealthSummary> getSummary({DateTime? date}) async {
    final query = <String, dynamic>{};
    if (date != null) query['date'] = _formatDate(date);

    return _apiClient.get<HealthSummary>(
      '/health/summary',
      queryParameters: query.isEmpty ? null : query,
      fromJson: (data) =>
          HealthSummary.fromJson(data as Map<String, dynamic>),
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
