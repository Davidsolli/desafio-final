import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_empty_state.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_button.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('OmniEmptyState', () {
    testWidgets('exibe Ã­cone e tÃ­tulo', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniEmptyState(
          icon: Icons.inbox,
          title: 'Nenhum item',
        ),
      ));
      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('Nenhum item'), findsOneWidget);
    });

    testWidgets('exibe subtitle quando fornecido', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniEmptyState(
          icon: Icons.inbox,
          title: 'Vazio',
          subtitle: 'Adicione algo para comeÃ§ar',
        ),
      ));
      expect(find.text('Adicione algo para comeÃ§ar'), findsOneWidget);
    });

    testWidgets('nÃ£o exibe subtitle quando ausente', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniEmptyState(icon: Icons.inbox, title: 'Vazio'),
      ));
      expect(find.byType(OmniButton), findsNothing);
    });

    testWidgets('exibe botÃ£o de aÃ§Ã£o quando onAction fornecido', (tester) async {
      bool called = false;
      await tester.pumpWidget(_wrap(
        OmniEmptyState(
          icon: Icons.add,
          title: 'Vazio',
          actionLabel: 'Adicionar',
          onAction: () => called = true,
        ),
      ));
      expect(find.byType(OmniButton), findsOneWidget);
      expect(find.text('Adicionar'), findsOneWidget);
      await tester.tap(find.byType(OmniButton));
      expect(called, isTrue);
    });

    testWidgets('nÃ£o exibe botÃ£o quando onAction Ã© null', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniEmptyState(icon: Icons.inbox, title: 'Vazio'),
      ));
      expect(find.byType(OmniButton), findsNothing);
    });
  });
}

