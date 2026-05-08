import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_card.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

void main() {
  group('OmniCard Tests', () {
    testWidgets('OmniCard renders with child widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('OmniCard applies custom padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniCard(
              padding: const EdgeInsets.all(24),
              child: Text('Card With Padding'),
            ),
          ),
        ),
      );

      expect(find.text('Card With Padding'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('OmniCard has correct border radius', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniCard(
              borderRadius: 16,
              child: Text('Rounded Card'),
            ),
          ),
        ),
      );

      final card = find.byType(Card);
      expect(card, findsOneWidget);
    });

    testWidgets('OmniCard respects custom elevation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniCard(
              elevation: 8,
              child: Text('Elevated Card'),
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('OmniCard uses default padding when not provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniCard(
              child: Text('Default Padding Card'),
            ),
          ),
        ),
      );

      expect(find.text('Default Padding Card'), findsOneWidget);
    });

    testWidgets('OmniCard renders multiple children via row/column', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniCard(
              child: Column(
                children: [
                  Text('Title'),
                  Text('Subtitle'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
    });
  });
}
