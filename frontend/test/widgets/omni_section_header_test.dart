import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_section_header.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('OmniSectionHeader', () {
    testWidgets('exibe tÃ­tulo', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniSectionHeader(title: 'Treinos Recentes'),
      ));
      expect(find.text('Treinos Recentes'), findsOneWidget);
    });

    testWidgets('exibe subtitle quando fornecido', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniSectionHeader(
          title: 'Metas',
          subtitle: 'Acompanhe seu progresso',
        ),
      ));
      expect(find.text('Acompanhe seu progresso'), findsOneWidget);
    });

    testWidgets('nÃ£o exibe subtitle quando ausente', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniSectionHeader(title: 'Metas'),
      ));
      // apenas o tÃ­tulo deve aparecer
      expect(find.text('Metas'), findsOneWidget);
    });

    testWidgets('exibe action widget quando fornecido', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniSectionHeader(
          title: 'Treinos',
          action: Text('Ver todas'),
        ),
      ));
      expect(find.text('Ver todas'), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('usa Column quando action Ã© null', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniSectionHeader(title: 'Treinos'),
      ));
      expect(find.byType(Row), findsNothing);
    });
  });
}

