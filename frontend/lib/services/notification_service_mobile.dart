import 'api_client.dart';

/// Implementação mobile — Firebase Push não configurado ainda.
/// Mantém a mesma interface do stub para que o app compile sem erros.
/// Quando Firebase for integrado, substituir este arquivo pela implementação completa.
class NotificationService {
  final ApiClient apiClient;

  NotificationService({required this.apiClient});

  Future<void> initialize() async {}

  Future<void> sendTokenToBackend(String token) async {}

  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/notifications/preferences',
        fromJson: (json) => json is Map<String, dynamic> ? json : {},
      );
      return response;
    } catch (e) {
      return {};
    }
  }

  Future<bool> updatePreferences(Map<String, dynamic> data) async {
    try {
      await apiClient.put(
        '/notifications/preferences',
        body: data,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getHistory({String? type, int limit = 20}) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/notifications/history',
        queryParameters: {
          'type': ?type,
          'limit': limit,
        },
        fromJson: (json) => json is Map<String, dynamic> ? json : {},
      );
      final data = response['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      await apiClient.post<Map<String, dynamic>>(
        '/notifications/mark-read',
        body: {'notification_id': notificationId},
        fromJson: (json) => json is Map<String, dynamic> ? json : {},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
