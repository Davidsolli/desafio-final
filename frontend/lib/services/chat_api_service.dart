import 'package:omniconnect_fitness/services/api_client.dart';

/// Resumo de uma conversa na listagem (Card 18.10).
///
/// Reflete o DTO `ConversationSummaryDTO` do backend.
class Conversation {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status;
  final String channel;
  final int? rating;
  final bool escalated;
  final int messageCount;

  Conversation({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.status,
    required this.channel,
    required this.rating,
    required this.escalated,
    required this.messageCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      status: json['status'] as String,
      channel: json['channel'] as String? ?? 'app',
      rating: json['rating'] as int?,
      escalated: json['escalated'] as bool? ?? false,
      messageCount: json['message_count'] as int? ?? 0,
    );
  }
}

/// Mensagem dentro de uma conversa (Card 18.10).
class ChatMessage {
  final String id;
  final String role;
  final String content;
  final int? latencyMs;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.latencyMs,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      latencyMs: json['latency_ms'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Detalhe completo de uma conversa (Card 18.10).
class ConversationDetail {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status;
  final bool escalated;
  final String? escalationReason;
  final int? rating;
  final String? feedback;
  final List<ChatMessage> messages;

  ConversationDetail({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.status,
    required this.escalated,
    required this.escalationReason,
    required this.rating,
    required this.feedback,
    required this.messages,
  });

  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    final rawMessages = (json['messages'] as List?) ?? const [];
    return ConversationDetail(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      status: json['status'] as String,
      escalated: json['escalated'] as bool? ?? false,
      escalationReason: json['escalation_reason'] as String?,
      rating: json['rating'] as int?,
      feedback: json['feedback'] as String?,
      messages: rawMessages
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Resposta paginada de listagem de conversas (Card 18.10).
class ConversationListResponse {
  final List<Conversation> conversations;
  final int total;
  final int page;

  ConversationListResponse({
    required this.conversations,
    required this.total,
    required this.page,
  });

  factory ConversationListResponse.fromJson(Map<String, dynamic> json) {
    final rawList = (json['conversations'] as List?) ?? const [];
    return ConversationListResponse(
      conversations: rawList
          .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
    );
  }
}

/// Cliente do módulo de Chat (Cards 18.10 e 19.9).
///
/// Endpoints consumidos:
/// - `GET /api/v1/chat/conversations?page=&limit=`
/// - `GET /api/v1/chat/conversations/{id}`
abstract class ChatApiService {
  Future<ConversationListResponse> getConversations({
    int page = 1,
    int limit = 20,
  });

  Future<ConversationDetail> getConversation(String conversationId);
}

/// Implementação padrão sobre o `ApiClient` do projeto.
class ChatApiServiceImpl implements ChatApiService {
  final ApiClient _apiClient;

  ChatApiServiceImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<ConversationListResponse> getConversations({
    int page = 1,
    int limit = 20,
  }) {
    return _apiClient.get<ConversationListResponse>(
      '/chat/conversations',
      queryParameters: {'page': page, 'limit': limit},
      fromJson: (data) =>
          ConversationListResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<ConversationDetail> getConversation(String conversationId) {
    return _apiClient.get<ConversationDetail>(
      '/chat/conversations/$conversationId',
      fromJson: (data) =>
          ConversationDetail.fromJson(data as Map<String, dynamic>),
    );
  }
}
