import 'package:omniconnect_fitness/services/api_client.dart';

/// Mensagem em uma conversa do chatbot
class ChatMessageModel {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: (json['id'] ?? json['message_id'] ?? '') as String,
      role: (json['role'] ?? 'assistant') as String,
      content: (json['content'] ?? '') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get formattedTime {
    return '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}

/// Resposta do endpoint send-message
class SendMessageResponse {
  final String messageId;
  final String conversationId;
  final String content;
  final DateTime createdAt;

  SendMessageResponse({
    required this.messageId,
    required this.conversationId,
    required this.content,
    required this.createdAt,
  });

  factory SendMessageResponse.fromJson(Map<String, dynamic> json) {
    return SendMessageResponse(
      messageId: (json['message_id'] ?? '') as String,
      conversationId: (json['conversation_id'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Serviço de chat que consome a API do chatbot RAG
///
/// Endpoints do backend:
///   POST  /api/v1/chat/send-message               → Enviar mensagem
///   GET   /api/v1/chat/conversations/{id}          → Histórico de conversa
class ChatService {
  final ApiClient _apiClient;

  ChatService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Envia uma mensagem para o chatbot e retorna a resposta do assistente.
  ///
  /// [conversationId] — null para iniciar nova conversa, UUID para continuar.
  Future<SendMessageResponse> sendMessage(
    String message, {
    String? conversationId,
  }) async {
    try {
      final body = <String, dynamic>{
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
      };

      final response = await _apiClient.post<SendMessageResponse>(
        '/chat/send-message',
        body: body,
        fromJson: (data) =>
            SendMessageResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Busca o histórico de mensagens de uma conversa.
  Future<List<ChatMessageModel>> getConversationHistory(
    String conversationId,
  ) async {
    try {
      final response = await _apiClient.get<List<ChatMessageModel>>(
        '/chat/conversations/$conversationId',
        fromJson: (data) {
          if (data is Map<String, dynamic> &&
              data.containsKey('messages')) {
            final msgs = data['messages'] as List<dynamic>;
            return msgs
                .whereType<Map<String, dynamic>>()
                .map((m) => ChatMessageModel.fromJson(m))
                .toList();
          }
          return <ChatMessageModel>[];
        },
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
