import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/services/chat_api_service.dart';

/// Testes unitários para os modelos consumidos pelo `ChatApiService`.
///
/// Cobrem o contrato JSON acordado com o backend (Etapa 1):
/// - `GET /api/v1/chat/conversations` → `ConversationListResponse`
/// - `GET /api/v1/chat/conversations/{id}` → `ConversationDetail`
void main() {
  group('Conversation.fromJson', () {
    test('parses required fields from backend response', () {
      final json = {
        'id': 'c1',
        'started_at': '2026-05-09T10:00:00Z',
        'ended_at': null,
        'status': 'ativa',
        'channel': 'app',
        'rating': null,
        'escalated': false,
        'message_count': 4,
      };

      final c = Conversation.fromJson(json);

      expect(c.id, 'c1');
      expect(c.status, 'ativa');
      expect(c.channel, 'app');
      expect(c.escalated, false);
      expect(c.messageCount, 4);
      expect(c.endedAt, isNull);
      expect(c.rating, isNull);
      expect(c.startedAt.toUtc().year, 2026);
    });

    test('parses optional fields when present', () {
      final json = {
        'id': 'c2',
        'started_at': '2026-05-08T08:00:00Z',
        'ended_at': '2026-05-08T08:30:00Z',
        'status': 'fechada',
        'channel': 'app',
        'rating': 5,
        'escalated': true,
        'message_count': 12,
      };

      final c = Conversation.fromJson(json);

      expect(c.endedAt, isNotNull);
      expect(c.rating, 5);
      expect(c.escalated, true);
    });
  });

  group('ChatMessage.fromJson', () {
    test('parses role, content and timestamps', () {
      final json = {
        'id': 'm1',
        'role': 'user',
        'content': 'Como faço supino?',
        'retrieved_documents': [],
        'latency_ms': null,
        'created_at': '2026-05-09T10:00:01Z',
      };

      final m = ChatMessage.fromJson(json);

      expect(m.id, 'm1');
      expect(m.role, 'user');
      expect(m.content, 'Como faço supino?');
      expect(m.latencyMs, isNull);
      expect(m.createdAt.toUtc().minute, 0);
    });

    test('parses assistant message with latency', () {
      final json = {
        'id': 'm2',
        'role': 'assistant',
        'content': 'Mantenha as escápulas retraídas...',
        'retrieved_documents': [],
        'latency_ms': 1234,
        'created_at': '2026-05-09T10:00:03Z',
      };

      final m = ChatMessage.fromJson(json);

      expect(m.role, 'assistant');
      expect(m.latencyMs, 1234);
    });
  });

  group('ConversationDetail.fromJson', () {
    test('parses messages list in chronological order', () {
      final json = {
        'id': 'c1',
        'started_at': '2026-05-09T10:00:00Z',
        'ended_at': null,
        'status': 'ativa',
        'escalated': false,
        'escalation_reason': null,
        'rating': null,
        'feedback': null,
        'messages': [
          {
            'id': 'm1',
            'role': 'user',
            'content': 'Pergunta 1',
            'retrieved_documents': [],
            'latency_ms': null,
            'created_at': '2026-05-09T10:00:01Z',
          },
          {
            'id': 'm2',
            'role': 'assistant',
            'content': 'Resposta 1',
            'retrieved_documents': [],
            'latency_ms': 800,
            'created_at': '2026-05-09T10:00:03Z',
          },
        ],
      };

      final detail = ConversationDetail.fromJson(json);

      expect(detail.id, 'c1');
      expect(detail.messages.length, 2);
      expect(detail.messages.first.role, 'user');
      expect(detail.messages.last.role, 'assistant');
      expect(detail.escalated, false);
    });

    test('handles empty messages list', () {
      final json = {
        'id': 'c2',
        'started_at': '2026-05-09T10:00:00Z',
        'ended_at': null,
        'status': 'ativa',
        'escalated': false,
        'escalation_reason': null,
        'rating': null,
        'feedback': null,
        'messages': <Map<String, dynamic>>[],
      };

      final detail = ConversationDetail.fromJson(json);
      expect(detail.messages, isEmpty);
    });
  });

  group('ConversationListResponse.fromJson', () {
    test('parses paginated list of conversations', () {
      final json = {
        'conversations': [
          {
            'id': 'c1',
            'started_at': '2026-05-09T10:00:00Z',
            'ended_at': null,
            'status': 'ativa',
            'channel': 'app',
            'rating': null,
            'escalated': false,
            'message_count': 3,
          },
          {
            'id': 'c2',
            'started_at': '2026-05-08T10:00:00Z',
            'ended_at': '2026-05-08T10:30:00Z',
            'status': 'fechada',
            'channel': 'app',
            'rating': 4,
            'escalated': false,
            'message_count': 8,
          },
        ],
        'total': 2,
        'page': 1,
      };

      final response = ConversationListResponse.fromJson(json);

      expect(response.conversations.length, 2);
      expect(response.total, 2);
      expect(response.page, 1);
    });

    test('handles empty list', () {
      final json = {
        'conversations': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
      };

      final response = ConversationListResponse.fromJson(json);

      expect(response.conversations, isEmpty);
      expect(response.total, 0);
    });
  });
}
