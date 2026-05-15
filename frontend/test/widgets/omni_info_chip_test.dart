import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_info_chip.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('OmniInfoChip', () {
    testWidgets('exibe label', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniInfoChip(label: '45 min'),
      ));
      expect(find.text('45 min'), findsOneWidget);
    });

    testWidgets('exibe Ã­cone quando fornecido', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniInfoChip(label: '45 min', icon: Icons.timer),
      ));
      expect(find.byIcon(Icons.timer), findsOneWidget);
    });

    testWidgets('nÃ£o exibe Ã­cone quando ausente', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniInfoChip(label: '45 min'),
      ));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('dispara onTap quando clicÃ¡vel', (tester) async {
      bool called = false;
      await tester.pumpWidget(_wrap(
        OmniInfoChip(
          label: 'Filtrar',
          onTap: () => called = true,
        ),
      ));
      await tester.tap(find.byType(OmniInfoChip));
      expect(called, isTrue);
    });

    testWidgets('nÃ£o envolve em GestureDetector quando onTap null', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniInfoChip(label: 'Info'),
      ));
      expect(find.byType(GestureDetector), findsNothing);
    });
  });
}

