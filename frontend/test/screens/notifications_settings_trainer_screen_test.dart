import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:omniconnect_fitness/screens/notifications_settings_trainer_screen.dart';
import 'package:omniconnect_fitness/services/notification_service.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

import '../test_helpers/fake_notification_service.dart';

void main() {
  group('NotificationsSettingsTrainerScreen', () {
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

    testWidgets('exibe toggle "Aluno Inativo" e secao "Alertas de Alunos"',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'student_inactivity_enabled': true,
      };

      await tester.pumpWidget(wrap(const NotificationsSettingsTrainerScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Aluno Inativo'), findsOneWidget);
      expect(find.text('Alertas de Alunos'), findsOneWidget);
      expect(find.byIcon(Icons.person_off), findsOneWidget);
    });

    testWidgets('NAO exibe toggles de cliente (treino, refeicao, novas fichas)',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'student_inactivity_enabled': true,
      };

      await tester.pumpWidget(wrap(const NotificationsSettingsTrainerScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Lembrete de Treino'), findsNothing);
      expect(find.text('Lembrete de Refeição'), findsNothing);
      expect(find.text('Novas Fichas'), findsNothing);
    });

    testWidgets('toggle "Aluno Inativo" chama updatePreferences',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'student_inactivity_enabled': true,
      };
      fake.updateOk = true;

      await tester.pumpWidget(wrap(const NotificationsSettingsTrainerScreen()));
      await tester.pumpAndSettle();

      // O primeiro switch é o master, o segundo é o student_inactivity
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();

      expect(fake.updateCalls, isNotEmpty);
      expect(
        fake.updateCalls.any(
          (call) => call.containsKey('student_inactivity_enabled'),
        ),
        isTrue,
        reason: 'updatePreferences deveria ser chamado com student_inactivity_enabled',
      );
    });

    testWidgets('exibe master switch e dropdown de timezone',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': true,
        'student_inactivity_enabled': true,
        'timezone': 'America/Sao_Paulo',
      };

      await tester.pumpWidget(wrap(const NotificationsSettingsTrainerScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ativar Notificações'), findsOneWidget);
      expect(find.text('Fuso horário'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets(
        'exibe mensagem de silenciamento (texto trainer) quando notif desabilitadas',
        (WidgetTester tester) async {
      fake.preferencesToReturn = <String, dynamic>{
        'notifications_enabled': false,
      };

      await tester.pumpWidget(wrap(const NotificationsSettingsTrainerScreen()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('alertas dos seus alunos'),
        findsOneWidget,
      );
    });
  });
}
