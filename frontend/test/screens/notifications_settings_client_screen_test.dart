import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:omniconnect_fitness/screens/notifications_settings_client_screen.dart';
import 'package:omniconnect_fitness/services/notification_service.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

import '../test_helpers/fake_notification_service.dart';

void main() {
  group('NotificationsSettingsClientScreen', () {
    late FakeNotificationService fake;

    setUp(() {
      fake = FakeNotificationService();
    });

    Widget wrap(Widget child) => MaterialApp(
          theme: AppTheme.darkTheme,
          home: MultiProvider(
            providers: [
              Provider<NotificationService>.value(value: fake),
            ],
            child: child,
          ),
        );

    testWidgets('exibe loading enquanto carrega preferências',
        (WidgetTester tester) async {
      fake.preferencesFuture = () => Future.delayed(
            const Duration(milliseconds: 100),
            () => <String, dynamic>{},
          );

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // limpa o future pendente para evitar estado de teste pendurado
      await tester.pumpAndSettle();
    });

    testWidgets('exibe título Notificações após carregamento',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{};

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Notificações'), findsWidgets);
    });

    testWidgets('exibe master switch de ativar notificações',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'workout_reminder_enabled': true,
        'meal_reminder_enabled': false,
        'new_workout_sheet_enabled': true,
      };

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ativar Notificações'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('exibe cards de lembretes quando notificações habilitadas',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'workout_reminder_enabled': true,
        'meal_reminder_enabled': false,
      };

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Lembretes'), findsOneWidget);
      expect(find.text('Lembrete de Treino'), findsOneWidget);
      expect(find.text('Lembrete de Refeição'), findsOneWidget);
      expect(find.text('Novas Fichas'), findsOneWidget);
    });

    testWidgets('exibe mensagem de silêncio quando notificações desabilitadas',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': false,
      };

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
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
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'workout_reminder_enabled': true,
        'meal_reminder_enabled': false,
        'new_workout_sheet_enabled': true,
      };
      fake.updateOk = true;

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(fake.updateCalls.length, greaterThan(0));
    });

    testWidgets('exibe ícones nos cards de preferência',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'workout_reminder_enabled': true,
        'meal_reminder_enabled': false,
        'new_workout_sheet_enabled': true,
      };

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.byIcon(Icons.assignment), findsOneWidget);
    });

    testWidgets('exibe SnackBar de erro quando updatePreferences falha',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'workout_reminder_enabled': true,
      };
      fake.updateOk = false;

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Falha ao atualizar preferência'), findsOneWidget);
    });

    testWidgets('scaffold tem AppBar e Scaffold renderizados',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{};

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    // ---- Fase 2: Timezone dropdown ----

    testWidgets('exibe dropdown de timezone com fusos brasileiros',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'workout_reminder_enabled': true,
        'timezone': 'America/Sao_Paulo',
      };

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Fuso horário'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('selecionar novo fuso chama updateTimezone',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'workout_reminder_enabled': true,
        'timezone': 'America/Sao_Paulo',
      };
      fake.updateTimezoneOk = true;

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Seleciona Manaus na lista de opções
      await tester.tap(find.text('Manaus (UTC-4)').last);
      await tester.pumpAndSettle();

      expect(fake.updateTimezoneCalls, contains('America/Manaus'));
    });

    testWidgets('exibe SnackBar de erro quando updateTimezone falha',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'workout_reminder_enabled': true,
        'timezone': 'America/Sao_Paulo',
      };
      fake.updateTimezoneOk = false;

      await tester.pumpWidget(wrap(const NotificationsSettingsClientScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manaus (UTC-4)').last);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Falha ao atualizar fuso horário'), findsOneWidget);
    });
  });
}
