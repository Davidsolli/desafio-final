/// Configuração centralizada de URLs da API
class ApiConfig {
  /// URL base do backend (HTTP/HTTPS)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// URL base do WebSocket
  static String? get wsBaseUrl {
    final base = baseUrl;
    // Converte http:// para ws:// e https:// para wss://
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    } else if (base.startsWith('http://')) {
      return base.replaceFirst('http://', 'ws://');
    }
    return null;
  }

  /// Endpoints da API
  static const String apiV1 = '$baseUrl/api/v1';

  // Chat endpoints
  static const String chatSendMessage = '$apiV1/chat/send-message';
  static const String chatConversations = '$apiV1/chat/conversations';
  static const String chatWebSocket = '$apiV1/chat/ws';

  // Auth endpoints
  static const String authLogin = '$apiV1/auth/login';
  static const String authLogout = '$apiV1/auth/logout';
  static const String authRefresh = '$apiV1/auth/refresh';
}
