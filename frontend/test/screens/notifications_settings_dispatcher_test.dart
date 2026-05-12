import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:omniconnect_fitness/providers/auth_provider.dart';
import 'package:omniconnect_fitness/screens/notifications_settings_screen.dart';
import 'package:omniconnect_fitness/screens/notifications_settings_client_screen.dart';
import 'package:omniconnect_fitness/screens/notifications_settings_trainer_screen.dart';
import 'package:omniconnect_fitness/services/notification_service.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

import '../test_helpers/fake_auth_provider.dart';
import '../test_helpers/fake_notification_service.dart';

void main() {
  group('NotificationsSettingsScreen (dispatcher por role)', () {
    late FakeNotificationService fakeService;

    setUp(() {
      fakeService = FakeNotificationService();
      fakeService.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
      };
    });

    AuthUser _user(String role) => AuthUser(
          id: 'u1',
          name: 'Test',
          email: 't@example.com',
          role: role,
        );

    Widget _wrap(AuthUser? user, {String? landingRoute}) {
      final fakeAuth = FakeAuthProvider(user: user);
      final router = GoRouter(
        initialLocation: '/notifications-settings',
        routes: [
          GoRoute(
            path: '/notifications-settings',
            builder: (_, __) => const NotificationsSettingsScreen(),
          ),
          GoRoute(
            path: '/admin/trainers',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('admin-dashboard')),
            ),
          ),
        ],
      );
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
          Provider<NotificationService>.value(value: fakeService),
        ],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      );
    }

    testWidgets('client → renderiza NotificationsSettingsClientScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_user('client')));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsSettingsClientScreen), findsOneWidget);
      expect(find.byType(NotificationsSettingsTrainerScreen), findsNothing);
    });

    testWidgets('personal_trainer → renderiza NotificationsSettingsTrainerScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_user('personal_trainer')));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsSettingsTrainerScreen), findsOneWidget);
      expect(find.byType(NotificationsSettingsClientScreen), findsNothing);
    });

    testWidgets('admin → redireciona para /admin/trainers',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_user('admin')));
      await tester.pumpAndSettle();

      // Após o redirect, a tela renderizada deve ser a do admin dashboard
      expect(find.text('admin-dashboard'), findsOneWidget);
      expect(find.byType(NotificationsSettingsClientScreen), findsNothing);
      expect(find.byType(NotificationsSettingsTrainerScreen), findsNothing);
    });

    testWidgets('user null → mostra loader (fallback)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(null));
      // sem pumpAndSettle pra não rodar timers infinitos do CircularProgressIndicator
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(NotificationsSettingsClientScreen), findsNothing);
      expect(find.byType(NotificationsSettingsTrainerScreen), findsNothing);
    });
  });
}
