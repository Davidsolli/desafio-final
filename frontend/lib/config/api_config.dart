import 'package:flutter/foundation.dart';

/// Configuração centralizada de URLs da API
class ApiConfig {
  /// URL base do backend (HTTP/HTTPS)
  /// Em modo release (servidor), usa a URL relativa /server02
  /// Em modo debug (local), usa o localhost:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? '/server02' : 'http://localhost:8000',
  );

  /// URL base do WebSocket
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
  static const String apiV1 = '$baseUrl/api/v1';

  // Chat endpoints
  static const String chatSendMessage = '$apiV1/chat/send-message';
  static const String chatSendAudio = '$apiV1/chat/send-audio';
  static const String chatConversations = '$apiV1/chat/conversations';
  static const String chatWebSocket = '$apiV1/chat/ws';

  // Auth endpoints
  static const String authLogin = '$apiV1/auth/login';
  static const String authLogout = '$apiV1/auth/logout';
  static const String authRefresh = '$apiV1/auth/refresh';
}

