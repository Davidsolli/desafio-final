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

  Future<List<Map<String, dynamic>>> getHistory({String? type, int limit = 20}) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/api/v1/notifications/history',
        queryParameters: {
          if (type != null) 'type': type,
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
        '/api/v1/notifications/mark-read',
        body: {'notification_id': notificationId},
        fromJson: (json) => json is Map<String, dynamic> ? json : {},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTimezone(String tz) async {
    try {
      await apiClient.put<Map<String, dynamic>>(
        '/api/v1/users/me/timezone',
        body: {'timezone': tz},
        fromJson: (json) => json is Map<String, dynamic> ? json : {},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
