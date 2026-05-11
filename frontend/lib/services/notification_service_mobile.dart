import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient apiClient;
  final FirebaseMessaging? _firebaseMessagingOverride;
  final FlutterLocalNotificationsPlugin _localNotifications;

  NotificationService({
    required this.apiClient,
    FirebaseMessaging? firebaseMessaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _firebaseMessagingOverride = firebaseMessaging,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  /// Lazy: só acessa FirebaseMessaging.instance dentro de initialize/handlers
  /// para que testes que não tocam FCM não exijam Firebase inicializado.
  FirebaseMessaging get _firebaseMessaging =>
      _firebaseMessagingOverride ?? FirebaseMessaging.instance;

  Future<void> initialize() async {
    await Firebase.initializeApp();

    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await sendTokenToBackend(token);
      }

      _firebaseMessaging.onTokenRefresh.listen(sendTokenToBackend);

      FirebaseMessaging.onMessage.listen(_showLocalNotification);
    }
  }

  Future<void> sendTokenToBackend(String token) async {
    try {
      await apiClient.put(
        '/api/v1/notifications/token',
        body: {'fcm_token': token},
        fromJson: (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      // token será re-enviado no próximo refresh
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'omniconnect_channel',
      'Lembretes OmniConnect',
      importance: Importance.max,
      priority: Priority.high,
    );
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      const NotificationDetails(android: androidDetails),
    );
  }

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
          if (type != null) 'notification_type': type,
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
