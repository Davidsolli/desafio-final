import 'api_client.dart';

/// Implementação stub para Web — push FCM não é suportado no navegador com firebase_messaging v14.
class NotificationService {
  final ApiClient apiClient;

  NotificationService({required this.apiClient});

  Future<void> initialize() async {}

  Future<void> sendTokenToBackend(String token) async {}

  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/api/v1/notifications/preferences',
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
        '/api/v1/notifications/preferences',
        body: data,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
