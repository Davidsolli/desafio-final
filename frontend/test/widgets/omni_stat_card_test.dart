import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_stat_card.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('OmniStatCard', () {
    testWidgets('exibe value e label', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniStatCard(value: '42', label: 'Treinos'),
      ));
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Treinos'), findsOneWidget);
    });

    testWidgets('exibe Ã­cone quando fornecido', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniStatCard(
          value: '7',
          label: 'Dias',
          icon: Icons.calendar_today,
        ),
      ));
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('nÃ£o exibe Ã­cone quando ausente', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniStatCard(value: '7', label: 'Dias'),
      ));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('exibe unit quando fornecido', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniStatCard(value: '85', label: 'Peso', unit: 'kg'),
      ));
      expect(find.text('kg'), findsOneWidget);
    });

    testWidgets('dispara onTap quando clicÃ¡vel', (tester) async {
      bool called = false;
      await tester.pumpWidget(_wrap(
        OmniStatCard(
          value: '5',
          label: 'Metas',
          onTap: () => called = true,
        ),
      ));
      await tester.tap(find.byType(OmniStatCard));
      expect(called, isTrue);
    });

    testWidgets('nÃ£o envolve em GestureDetector quando onTap null', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniStatCard(value: '5', label: 'Metas'),
      ));
      expect(find.byType(GestureDetector), findsNothing);
    });
  });
}

