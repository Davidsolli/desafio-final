import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_avatar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('OmniAvatar', () {
    testWidgets('exibe inicial do nome em maiÃºsculo', (tester) async {
      await tester.pumpWidget(_wrap(const OmniAvatar(name: 'anderson')));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('exibe ? quando name Ã© vazio', (tester) async {
      await tester.pumpWidget(_wrap(const OmniAvatar(name: '')));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('usa CircleAvatar no modo sÃ³lido', (tester) async {
      await tester.pumpWidget(_wrap(const OmniAvatar(name: 'JoÃ£o')));
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('usa Container com gradient quando useGradient true', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniAvatar(name: 'JoÃ£o', useGradient: true),
      ));
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('respeita parÃ¢metro size', (tester) async {
      await tester.pumpWidget(_wrap(
        const OmniAvatar(name: 'Ana', size: 60),
      ));
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, equals(30.0));
    });
  });
}

