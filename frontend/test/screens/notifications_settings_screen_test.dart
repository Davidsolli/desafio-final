import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:omniconnect_fitness/screens/notifications_settings_screen.dart';
import 'package:omniconnect_fitness/services/notification_service.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

import 'notifications_settings_screen_test.mocks.dart';

@GenerateMocks([NotificationService])
void main() {
  group('NotificationsSettingsScreen', () {
    late MockNotificationService mockNotificationService;

    setUp(() {
      mockNotificationService = MockNotificationService();
    });

    Widget wrap(Widget child) => MaterialApp(
          theme: AppTheme.darkTheme,
          home: MultiProvider(
            providers: [
              Provider<NotificationService>.value(
                value: mockNotificationService,
              ),
            ],
            child: child,
          ),
        );

    testWidgets('exibe loading enquanto carrega preferências',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences()).thenAnswer(
        (_) => Future.delayed(
          const Duration(milliseconds: 100),
          () => <String, dynamic>{},
        ),
      );

      await tester.pumpWidget(wrap(const NotificationsSettingsScreen()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exibe título Notificações após carregamento',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences())
          .thenAnswer((_) async => <String, dynamic>{});

      await tester.pumpWidget(wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Notificações'), findsWidgets);
    });

    testWidgets('exibe master switch de ativar notificações',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences())
          .thenAnswer((_) async => <String, dynamic>{
                'notifications_enabled': true,
                'workout_reminder_enabled': true,
                'meal_reminder_enabled': false,
                'new_workout_sheet_enabled': true,
              });

      await tester.pumpWidget(wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ativar Notificações'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('exibe cards de lembretes quando notificações habilitadas',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences())
          .thenAnswer((_) async => <String, dynamic>{
                'notifications_enabled': true,
                'workout_reminder_enabled': true,
                'meal_reminder_enabled': false,
              });

      await tester.pumpWidget(wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Lembretes'), findsOneWidget);
      expect(find.text('Lembrete de Treino'), findsOneWidget);
      expect(find.text('Lembrete de Refeição'), findsOneWidget);
      expect(find.text('Novas Fichas'), findsOneWidget);
    });

    testWidgets('exibe mensagem de silêncio quando notificações desabilitadas',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences())
          .thenAnswer((_) async => <String, dynamic>{
                'notifications_enabled': false,
              });

      await tester.pumpWidget(wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Todas as notificações estão silenciadas. Você não receberá lembretes de treinos nem avisos de metas.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('clicar no switch chama updatePreferences',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences())
          .thenAnswer((_) async => <String, dynamic>{
                'notifications_enabled': true,
                'workout_reminder_enabled': true,
                'meal_reminder_enabled': false,
                'new_workout_sheet_enabled': true,
              });

      when(mockNotificationService.updatePreferences(any))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      verify(mockNotificationService.updatePreferences(any))
          .called(greaterThan(0));
    });

    testWidgets('exibe ícones nos cards de preferência',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences())
          .thenAnswer((_) async => <String, dynamic>{
                'notifications_enabled': true,
                'workout_reminder_enabled': true,
                'meal_reminder_enabled': false,
                'new_workout_sheet_enabled': true,
              });

      await tester.pumpWidget(wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.byIcon(Icons.assignment), findsOneWidget);
    });

    testWidgets('exibe SnackBar de erro quando updatePreferences falha',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences())
          .thenAnswer((_) async => <String, dynamic>{
                'notifications_enabled': true,
                'workout_reminder_enabled': true,
              });

      when(mockNotificationService.updatePreferences(any))
          .thenAnswer((_) async => false);

      await tester.pumpWidget(wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Falha ao atualizar preferência'), findsOneWidget);
    });

    testWidgets('scaffold tem AppBar e Scaffold renderizados',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences())
          .thenAnswer((_) async => <String, dynamic>{});

      await tester.pumpWidget(wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
