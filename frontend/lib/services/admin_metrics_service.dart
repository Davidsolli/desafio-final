import 'api_client.dart';
import '../models/admin_metrics_models.dart';

class AdminMetricsService {
  final ApiClient _apiClient;

  AdminMetricsService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<PaginatedStudentMetricsDTO> getStudentMetrics({
    int days = 30,
    String? trainerId,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{
      'days': days,
      'page': page,
      'limit': limit,
      if (trainerId != null) 'trainer_id': trainerId,
    };
    return _apiClient.get<PaginatedStudentMetricsDTO>(
      '/admin/metrics/students',
      queryParameters: params,
      fromJson: (json) =>
          PaginatedStudentMetricsDTO.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<PaginatedTrainerMetricsDTO> getTrainerMetrics({
    int days = 30,
    int page = 1,
    int limit = 50,
  }) async {
    return _apiClient.get<PaginatedTrainerMetricsDTO>(
      '/admin/metrics/trainers',
      queryParameters: {'days': days, 'page': page, 'limit': limit},
      fromJson: (json) =>
          PaginatedTrainerMetricsDTO.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<SystemMetricsDTO> getSystemMetrics({int days = 30}) async {
    return _apiClient.get<SystemMetricsDTO>(
      '/admin/metrics/system',
      queryParameters: {'days': days},
      fromJson: (json) =>
          SystemMetricsDTO.fromJson(json as Map<String, dynamic>),
    );
  }

}
