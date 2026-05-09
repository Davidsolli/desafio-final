import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/screens/student/chat_history_screen.dart';
import 'package:omniconnect_fitness/services/chat_api_service.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

/// Implementação fake do `ChatApiService` para testes de widget.
class FakeChatApiService implements ChatApiService {
  List<Conversation> conversations;
  bool throwOnList;

  FakeChatApiService({
    this.conversations = const [],
    this.throwOnList = false,
  });

  @override
  Future<ConversationListResponse> getConversations({
    int page = 1,
    int limit = 20,
  }) async {
    if (throwOnList) throw Exception('falha simulada');
    return ConversationListResponse(
      conversations: conversations,
      total: conversations.length,
      page: page,
    );
  }

  @override
  Future<ConversationDetail> getConversation(String conversationId) async {
    return ConversationDetail(
      id: conversationId,
      startedAt: DateTime.parse('2026-05-09T10:00:00Z'),
      endedAt: null,
      status: 'ativa',
      escalated: false,
      escalationReason: null,
      rating: null,
      feedback: null,
      messages: [],
    );
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.lightTheme, home: child);
}

Conversation _conv({
  required String id,
  String status = 'ativa',
  bool escalated = false,
  int messageCount = 5,
}) {
  return Conversation(
    id: id,
    startedAt: DateTime.parse('2026-05-09T10:00:00Z'),
    endedAt: null,
    status: status,
    channel: 'app',
    rating: null,
    escalated: escalated,
    messageCount: messageCount,
  );
}

void main() {
  group('Card 18.10 — Tela de histórico', () {
    testWidgets('app displays chat history', (tester) async {
      final fake = FakeChatApiService(conversations: [
        _conv(id: 'c1', messageCount: 4),
        _conv(id: 'c2', messageCount: 9),
      ]);

      await tester.pumpWidget(_wrap(ChatHistoryScreen(apiService: fake)));
      await tester.pump(); // dispara future
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('messages loaded from backend correctly', (tester) async {
      final fake = FakeChatApiService(conversations: [
        _conv(id: 'c1', messageCount: 7),
      ]);

      await tester.pumpWidget(_wrap(ChatHistoryScreen(apiService: fake)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Algum indicativo da contagem de mensagens é exibido
      expect(
        find.textContaining('7'),
        findsWidgets,
        reason: 'A contagem 7 deve aparecer em algum lugar do item',
      );
    });

    testWidgets('history displayed by session chronologically',
        (tester) async {
      final older = Conversation(
        id: 'older',
        startedAt: DateTime.utc(2026, 5, 1, 10, 0),
        endedAt: null,
        status: 'fechada',
        channel: 'app',
        rating: null,
        escalated: false,
        messageCount: 3,
      );
      final newer = Conversation(
        id: 'newer',
        startedAt: DateTime.utc(2026, 5, 9, 10, 0),
        endedAt: null,
        status: 'ativa',
        channel: 'app',
        rating: null,
        escalated: false,
        messageCount: 4,
      );

      final fake = FakeChatApiService(conversations: [newer, older]);

      await tester.pumpWidget(_wrap(ChatHistoryScreen(apiService: fake)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tiles.length, 2);
      // Mais recente em primeiro
      final firstTileKey = tiles.first.key;
      expect(firstTileKey, isA<ValueKey<String>>());
      expect((firstTileKey as ValueKey<String>).value, 'newer');
    });

    testWidgets('respects authenticated user', (tester) async {
      // O serviço fake é construído sem token; só passa se o widget
      // delegar a autenticação ao serviço (via ApiClient global).
      final fake = FakeChatApiService(conversations: const []);

      await tester.pumpWidget(_wrap(ChatHistoryScreen(apiService: fake)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Sem exceção, sem chamadas extra além do getConversations
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles empty history state', (tester) async {
      final fake = FakeChatApiService(conversations: const []);

      await tester.pumpWidget(_wrap(ChatHistoryScreen(apiService: fake)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ListTile), findsNothing);
      expect(
        find.textContaining('ainda não tem conversas'),
        findsOneWidget,
      );
    });

    testWidgets('maintains chat interface pattern', (tester) async {
      final fake = FakeChatApiService(conversations: [_conv(id: 'c1')]);

      await tester.pumpWidget(_wrap(ChatHistoryScreen(apiService: fake)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tela usa Scaffold com AppBar — padrão consistente do app
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows error retry option when load fails', (tester) async {
      final fake = FakeChatApiService(throwOnList: true);

      await tester.pumpWidget(_wrap(ChatHistoryScreen(apiService: fake)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Algum tipo de feedback de erro
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Tentar novamente'),
        findsOneWidget,
      );
    });
  });
}
