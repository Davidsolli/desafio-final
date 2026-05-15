import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:omniconnect_fitness/config/api_config.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Cliente SSE para o chatbot Vitali.
///
/// Substitui o WebSocket em ambientes onde o proxy reverso faz downgrade
/// para HTTP/1.0 (caso do proxy externo da Alpha), o que mata o handshake
/// de upgrade WebSocket. SSE funciona em HTTP/1.0 e atravessa proxies
/// tradicionais sem cerimônia.
///
/// Cada chamada de [sendMessageStream] é uma requisição HTTP independente
/// (não há conexão persistente como no WebSocket).
class ChatStreamService {
  final http.Client _client;

  ChatStreamService({http.Client? client}) : _client = client ?? http.Client();

  /// Envia uma mensagem para o chatbot e retorna um stream de eventos
  /// do servidor.
  ///
  /// Eventos possíveis (campo `type`):
  ///   - `status` → `{type, status, message}` — progresso (thinking, searching...)
  ///   - `chunk`  → `{type, content}` — fragmento de texto da resposta
  ///   - `final`  → `{type, message_id, conversation_id, ...}` — fim + metadados
  ///   - `error`  → `{type, code, error}` — erro tratado pelo backend
  ///
  /// Lança [UnauthorizedException] se o token JWT for inválido (401).
  /// Lança [ApiException] para outros erros HTTP antes do streaming começar.
  /// Erros de rede durante o streaming são emitidos via `onError` do stream.
  Stream<Map<String, dynamic>> sendMessageStream({
    required String message,
    required String token,
    String? conversationId,
  }) async* {
    final uri = Uri.parse('${ApiConfig.apiV1}/chat/send-message/stream');

    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode({
        'message': message,
        if (conversationId != null && conversationId.isNotEmpty)
          'conversation_id': conversationId,
      });

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } on http.ClientException catch (e) {
      throw NetworkException(message: 'Erro de conexão: ${e.message}');
    }

    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      final errMsg = _extractErrorMessage(body);
      if (streamed.statusCode == 401) {
        throw UnauthorizedException(message: errMsg);
      }
      if (streamed.statusCode == 404) {
        throw NotFoundException(message: errMsg);
      }
      throw ApiException(message: errMsg, statusCode: streamed.statusCode);
    }

    // Parser SSE: eventos separados por "\n\n", cada um com linhas tipo
    // "data: {json}". Acumula bytes num buffer até completar um evento.
    String buffer = '';
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final idx = buffer.indexOf('\n\n');
        if (idx < 0) break;
        final rawEvent = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 2);

        for (final line in rawEvent.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final payload = line.substring(6);
          if (payload.isEmpty) continue;
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            yield json;
          } catch (_) {
            // Linha mal-formada — ignora pra não quebrar o stream inteiro
          }
        }
      }
    }
  }

  /// Fecha o cliente HTTP e cancela qualquer stream em andamento.
  void dispose() => _client.close();

  String _extractErrorMessage(String body) {
    try {
      if (body.isEmpty) return 'Erro desconhecido';
      final data = jsonDecode(body) as Map<String, dynamic>;
      final detail = data['detail'];
      if (detail is Map) {
        return detail['message'] as String? ?? 'Erro desconhecido';
      }
      return detail as String? ?? 'Erro desconhecido';
    } catch (_) {
      return 'Erro desconhecido';
    }
  }
}
