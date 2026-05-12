import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:omniconnect_fitness/screens/notifications_screen.dart';
import 'package:omniconnect_fitness/services/notification_service.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

import '../test_helpers/fake_notification_service.dart';

void main() {
  group('NotificationsScreen', () {
    late FakeNotificationService fakeService;

    setUp(() {
      fakeService = FakeNotificationService();
    });

    Widget _wrap(Widget child) {
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(path: '/notifications', builder: (_, __) => child),
        ],
      );
      return MultiProvider(
        providers: [
          Provider<NotificationService>.value(value: fakeService),
        ],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      );
    }

    testWidgets('carrega histórico da API e renderiza itens',
        (WidgetTester tester) async {
      fakeService.historyToReturn = [
        {
          'id': 'n1',
          'notification_type': 'workout_reminder',
          'title': 'Hora do treino',
          'body': 'Treino A está programado',
          'created_at': '2026-05-08T10:00:00Z',
          'read_at': null,
        },
        {
          'id': 'n2',
          'notification_type': 'achievement',
          'title': 'Meta concluída',
          'body': 'Parabéns',
          'created_at': '2026-05-07T18:30:00Z',
          'read_at': '2026-05-07T19:00:00Z',
        },
      ];

      await tester.pumpWidget(_wrap(const NotificationsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Hora do treino'), findsOneWidget);
      expect(find.text('Meta concluída'), findsOneWidget);
      expect(fakeService.historyCallCount, equals(1));
    });

    testWidgets('exibe estado vazio quando histórico está vazio',
        (WidgetTester tester) async {
      fakeService.historyToReturn = [];

      await tester.pumpWidget(_wrap(const NotificationsScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhuma notificação'), findsOneWidget);
    });

    testWidgets('exibe estado de erro quando service lança',
        (WidgetTester tester) async {
      fakeService.throwOnHistory = true;

      await tester.pumpWidget(_wrap(const NotificationsScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Erro ao carregar'), findsOneWidget);
    });

    testWidgets('toque em notificação não-lida chama markAsRead',
        (WidgetTester tester) async {
      fakeService.historyToReturn = [
        {
          'id': 'unread-1',
          'notification_type': 'workout_reminder',
          'title': 'Hora do treino',
          'body': 'Treino A',
          'created_at': '2026-05-08T10:00:00Z',
          'read_at': null,
        },
      ];

      await tester.pumpWidget(_wrap(const NotificationsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hora do treino'));
      await tester.pumpAndSettle();

      expect(fakeService.markReadIds, equals(['unread-1']));
    });

    testWidgets('toque em notificação já lida NÃO chama markAsRead',
        (WidgetTester tester) async {
      fakeService.historyToReturn = [
        {
          'id': 'read-1',
          'notification_type': 'achievement',
          'title': 'Meta concluída',
          'body': 'Parabéns',
          'created_at': '2026-05-07T18:30:00Z',
          'read_at': '2026-05-07T19:00:00Z',
        },
      ];

      await tester.pumpWidget(_wrap(const NotificationsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Meta concluída'));
      await tester.pumpAndSettle();

      expect(fakeService.markReadIds, isEmpty);
    });
  });
}
