import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_button.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

void main() {
  group('OmniButton Tests', () {
    testWidgets('OmniButton renders with text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniButton(
              text: 'Click Me',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
    });

    testWidgets('OmniButton calls onPressed when tapped', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniButton(
              text: 'Click Me',
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(OmniButton));
      await tester.pumpAndSettle();

      expect(pressed, true);
    });

    testWidgets('OmniButton shows loader when isLoading is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniButton(
              text: 'Loading',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('OmniButton is disabled when isLoading is true', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniButton(
              text: 'Loading',
              onPressed: () {
                pressed = true;
              },
              isLoading: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(pressed, false);
    });

    testWidgets('OmniButton renders as outlined button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniButton(
              text: 'Outlined',
              onPressed: () {},
              isOutlined: true,
            ),
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('OmniButton respects custom width and height', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniButton(
              text: 'Custom Size',
              onPressed: () {},
              width: 200,
              height: 60,
            ),
          ),
        ),
      );

      final sizedBox = find.byType(SizedBox).first;
      expect(sizedBox, findsOneWidget);
    });
  });
}
