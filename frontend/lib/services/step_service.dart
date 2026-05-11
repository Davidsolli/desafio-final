import 'package:omniconnect_fitness/models/step_models.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Serviço HTTP para o módulo de contador de passos.
class StepService {
  final ApiClient _apiClient;

  StepService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Sincroniza os passos do dia com o backend.
  /// Retorna o registro consolidado (incluindo flag de recorde semanal).
  Future<StepLog> syncSteps({
    required DateTime date,
    required int steps,
    required double distanceMeters,
  }) async {
    final dateString = _formatDate(date);
    return _apiClient.post<StepLog>(
      '/steps/sync',
      body: {
        'date': dateString,
        'steps': steps,
        'distance_meters': distanceMeters,
      },
      fromJson: (data) => StepLog.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Histórico do próprio usuário.
  Future<StepHistory> getMyHistory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, dynamic>{};
    if (startDate != null) query['start_date'] = _formatDate(startDate);
    if (endDate != null) query['end_date'] = _formatDate(endDate);

    return _apiClient.get<StepHistory>(
      '/steps/history',
      queryParameters: query.isEmpty ? null : query,
      fromJson: (data) => StepHistory.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Histórico de um aluno específico (chamado pelo personal trainer).
  Future<StepHistory> getStudentHistory(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, dynamic>{};
    if (startDate != null) query['start_date'] = _formatDate(startDate);
    if (endDate != null) query['end_date'] = _formatDate(endDate);

    return _apiClient.get<StepHistory>(
      '/steps/student/$userId/history',
      queryParameters: query.isEmpty ? null : query,
      fromJson: (data) => StepHistory.fromJson(data as Map<String, dynamic>),
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
