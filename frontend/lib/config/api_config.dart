import 'package:flutter/foundation.dart';

/// Configuração centralizada de URLs da API
class ApiConfig {
  /// Valor cru da variável de ambiente — pode vir com trailing slash.
  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? '/server02' : 'http://localhost:8000',
  );

  /// URL base do backend (HTTP/HTTPS), sempre sem trailing slash.
  /// Evita gerar URLs com "//" no path quando concatenada com endpoints.
  static final String baseUrl =
      _rawBaseUrl.endsWith('/') ? _rawBaseUrl.substring(0, _rawBaseUrl.length - 1) : _rawBaseUrl;

  /// URL base do WebSocket
  /// Em modo release (servidor), usa a URL relativa /server02
  /// Em modo debug (local), usa o localhost:8000
  static String? get wsBaseUrl {
    if (baseUrl.startsWith('http')) {
      return baseUrl.replaceFirst('http', 'ws');
    }

    // Em produção (Web), se a URL for relativa, usamos o domínio atual do navegador
    if (kReleaseMode) {
      final Uri currentUri = Uri.base;
      final String protocol = currentUri.scheme == 'https' ? 'wss' : 'ws';
      final String host = currentUri.host;
      final int port = currentUri.port;

      // Constrói algo como: ws://lab.alphaedtech.org.br/server02
      final String portSuffix = (port == 80 || port == 443 || port == 0) ? '' : ':$port';
      return '$protocol://$host$portSuffix$baseUrl';
    }

    return null;
  }

  /// Endpoints da API
  static final String apiV1 = '$baseUrl/api/v1';

  // Chat endpoints
  static final String chatSendMessage = '$apiV1/chat/send-message';
  static final String chatSendAudio = '$apiV1/chat/send-audio';
  static final String chatSendPhoto = '$apiV1/chat/send-photo';
  static final String chatConversations = '$apiV1/chat/conversations';
  static final String chatWebSocket = '$apiV1/chat/ws';

  // Auth endpoints
  static final String authLogin = '$apiV1/auth/login';
  static final String authLogout = '$apiV1/auth/logout';
  static final String authRefresh = '$apiV1/auth/refresh';
}
