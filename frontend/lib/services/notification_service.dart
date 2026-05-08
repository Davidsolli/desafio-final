import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient apiClient;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  NotificationService({required this.apiClient});

  Future<void> initialize() async {
    // 1. Pedir Permissão (Importante no iOS, no Android 13+ abre popup nativo)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Usuário aceitou as notificações.');
      
      // 2. Pegar o Token FCM
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await sendTokenToBackend(token);
      }

      // 3. Ouvir quando o token for atualizado
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        sendTokenToBackend(newToken);
      });

      // 4. Configurar handler para quando o app está aberto (foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });
    }
  }

  Future<void> sendTokenToBackend(String token) async {
    try {
      await apiClient.put(
        '/api/v1/notifications/token',
        body: {'fcm_token': token},
        fromJson: (json) => json as Map<String, dynamic>,
      );
      print('Token enviado ao backend com sucesso');
    } catch (e) {
      print('Erro ao enviar token FCM pro backend: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) async {
    // Config básica para mostrar notificação heads-up quando o app tá aberto
    const androidDetails = AndroidNotificationDetails(
      'omniconnect_channel', // id do canal
      'Lembretes OmniConnect', // nome do canal
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      platformDetails,
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
      print('Erro ao carregar preferências: $e');
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
      print('Erro ao atualizar preferências: $e');
      return false;
    }
  }
}
