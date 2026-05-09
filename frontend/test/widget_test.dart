// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_app_bar.dart';

void main() {
  testWidgets('Tema e componentes base da aplicação renderizam corretamente',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          appBar: OmniAppBar(title: 'OmniConnect Fitness'),
          body: const Center(child: Text('Bem-vindo')),
        ),
      ),
    );

    expect(find.text('OmniConnect Fitness'), findsOneWidget);
    expect(find.text('Bem-vindo'), findsOneWidget);
    expect(find.byType(OmniAppBar), findsOneWidget);
  });
}
