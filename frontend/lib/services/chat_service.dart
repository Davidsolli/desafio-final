import 'package:omniconnect_fitness/services/api_client.dart';

/// Mensagem de uma conversa retornada pelo backend.
class ChatMessageDTO {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  ChatMessageDTO({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageDTO.fromJson(Map<String, dynamic> json) {
    return ChatMessageDTO(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Detalhe completo de uma conversa, com mensagens.
class ConversationDetailDTO {
  final String id;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<ChatMessageDTO> messages;

  ConversationDetailDTO({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.messages,
  });

  factory ConversationDetailDTO.fromJson(Map<String, dynamic> json) {
    final raw = (json['messages'] as List<dynamic>? ?? []);
    return ConversationDetailDTO(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'active',
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      messages: raw
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageDTO.fromJson)
          .toList(),
    );
  }
}

/// Cliente HTTP do módulo de chat.
///
/// O envio de mensagens em tempo real continua via WebSocket
/// (chat_screen.dart). Este service cobre operações REST: carregar
/// histórico de uma conversa salva localmente, listar conversas
/// anteriores, etc.
class ChatService {
  final ApiClient _apiClient;

  ChatService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Busca o detalhe de uma conversa, incluindo todas as mensagens
  /// trocadas. Lança [NotFoundException] se a conversa não existe ou
  /// não pertence ao usuário autenticado.
  Future<ConversationDetailDTO> getConversation(String conversationId) async {
    return _apiClient.get<ConversationDetailDTO>(
      '/chat/conversations/$conversationId',
      fromJson: (data) =>
          ConversationDetailDTO.fromJson(data as Map<String, dynamic>),
    );
  }
}
