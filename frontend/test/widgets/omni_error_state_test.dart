import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_error_state.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('OmniErrorState', () {
    testWidgets('exibe mensagem e Ã­cone padrÃ£o', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniErrorState(message: 'Algo deu errado'),
      ));
      expect(find.text('Algo deu errado'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('exibe Ã­cone customizado', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniErrorState(
          message: 'Sem conexÃ£o',
          icon: Icons.wifi_off,
        ),
      ));
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('exibe botÃ£o retry quando onRetry fornecido', (tester) async {
      bool called = false;
      await tester.pumpWidget(_wrap(
        OmniErrorState(
          message: 'Erro',
          onRetry: () => called = true,
        ),
      ));
      expect(find.byType(OmniButton), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      await tester.tap(find.byType(OmniButton));
      expect(called, isTrue);
    });

    testWidgets('nÃ£o exibe botÃ£o retry quando onRetry Ã© null', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniErrorState(message: 'Erro'),
      ));
      expect(find.byType(OmniButton), findsNothing);
    });

    testWidgets('usa retryLabel customizado', (tester) async {
      await tester.pumpWidget(_wrap(
        OmniErrorState(
          message: 'Erro',
          onRetry: () {},
          retryLabel: 'Recarregar',
        ),
      ));
      expect(find.text('Recarregar'), findsOneWidget);
    });
  });
}

