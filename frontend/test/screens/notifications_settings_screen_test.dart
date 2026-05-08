import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:omniconnect_fitness/screens/notifications_settings_screen.dart';
import 'package:omniconnect_fitness/services/notification_service.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  group('NotificationsSettingsScreen', () {
    late MockNotificationService mockNotificationService;

    setUp(() {
      mockNotificationService = MockNotificationService();
    });

    Widget _wrap(Widget child) => MaterialApp(
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
      // Mock para delay
      when(mockNotificationService.getPreferences()).thenAnswer(
        (_) => Future.delayed(Duration(milliseconds: 100), () => {}),
      );

      await tester.pumpWidget(_wrap(const NotificationsSettingsScreen()));

      // Deve mostrar loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exibe título Notificações', (WidgetTester tester) async {
      when(mockNotificationService.getPreferences())
          .thenAnswer((_) async => {});

      await tester.pumpWidget(_wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Notificações'), findsWidgets);
    });

    testWidgets('exibe master switch de ativar notificações',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences()).thenAnswer((_) async => {
            'notifications_enabled': true,
            'workout_reminder_enabled': true,
            'meal_reminder_enabled': false,
            'new_workout_sheet_enabled': true,
          });

      await tester.pumpWidget(_wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ativar Notificações'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('exibe lembretes quando notificações habilitadas',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences()).thenAnswer((_) async => {
            'notifications_enabled': true,
            'workout_reminder_enabled': true,
            'meal_reminder_enabled': false,
          });

      await tester.pumpWidget(_wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Lembretes'), findsOneWidget);
      expect(find.text('Lembrete de Treino'), findsOneWidget);
      expect(find.text('Lembrete de Refeição'), findsOneWidget);
      expect(find.text('Novas Fichas'), findsOneWidget);
    });

    testWidgets('exibe mensagem quando notificações desabilitadas',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences()).thenAnswer((_) async => {
            'notifications_enabled': false,
          });

      await tester.pumpWidget(_wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Todas as notificações estão silenciadas. Você não receberá lembretes de treinos nem avisos de metas.'),
        findsOneWidget,
      );
    });

    testWidgets('atualiza preferência ao clicar no switch',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences()).thenAnswer((_) async => {
            'notifications_enabled': true,
            'workout_reminder_enabled': true,
            'meal_reminder_enabled': false,
            'new_workout_sheet_enabled': true,
          });

      when(mockNotificationService.updatePreferences(any))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(_wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      // Encontrar e clicar no primeiro switch
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Verificar se foi chamado
      verify(mockNotificationService.updatePreferences(any)).called(greaterThan(0));
    });

    testWidgets('exibe ícones nos cards de preferência',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences()).thenAnswer((_) async => {
            'notifications_enabled': true,
            'workout_reminder_enabled': true,
            'meal_reminder_enabled': false,
            'new_workout_sheet_enabled': true,
          });

      await tester.pumpWidget(_wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      // Verificar ícones
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.byIcon(Icons.assignment), findsOneWidget);
    });

    testWidgets('exibe erro ao falhar atualização',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences()).thenAnswer((_) async => {
            'notifications_enabled': true,
            'workout_reminder_enabled': true,
          });

      when(mockNotificationService.updatePreferences(any))
          .thenAnswer((_) async => false);

      await tester.pumpWidget(_wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      // Clicar switch
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Verificar se snackbar aparece (erro)
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Falha ao atualizar preferência'), findsOneWidget);
    });

    testWidgets('scaffold tem AppBar com título',
        (WidgetTester tester) async {
      when(mockNotificationService.getPreferences()).thenAnswer((_) async => {});

      await tester.pumpWidget(_wrap(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
