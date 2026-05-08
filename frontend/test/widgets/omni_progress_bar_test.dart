import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_progress_bar.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('OmniProgressBar', () {
    testWidgets('renderiza LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniProgressBar(value: 0.5),
      ));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('exibe label e trailingLabel', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniProgressBar(
          value: 0.7,
          label: 'Progresso',
          trailingLabel: '70%',
        ),
      ));
      expect(find.text('Progresso'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
    });

    testWidgets('nÃ£o exibe Row de labels quando ambos ausentes', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniProgressBar(value: 0.3),
      ));
      expect(find.byType(Row), findsNothing);
    });

    testWidgets('clamp: valor acima de 1.0 fica em 1.0', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniProgressBar(value: 2.0),
      ));
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, equals(1.0));
    });

    testWidgets('clamp: valor abaixo de 0.0 fica em 0.0', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniProgressBar(value: -0.5),
      ));
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, equals(0.0));
    });
  });
}

