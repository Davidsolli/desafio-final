import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_status_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('OmniStatusBadge', () {
    testWidgets('exibe label', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniStatusBadge(label: 'Ativo', color: Colors.green),
      ));
      expect(find.text('Ativo'), findsOneWidget);
    });

    testWidgets('chip usa borderRadius 6', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniStatusBadge(label: 'Pendente', color: Colors.orange),
      ));
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(6));
      expect(decoration.border, isNull);
    });

    testWidgets('pill usa borderRadius 20 e tem borda', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniStatusBadge(
          label: 'Em andamento',
          color: Colors.blue,
          isPill: true,
        ),
      ));
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(20));
      expect(decoration.border, isNotNull);
    });
  });
}

