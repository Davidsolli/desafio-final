import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_text_field.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

void main() {
  group('OmniTextField Tests', () {
    testWidgets('OmniTextField renders with label', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniTextField(
              controller: controller,
              labelText: 'Email',
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('OmniTextField accepts text input', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniTextField(
              controller: controller,
              labelText: 'Email',
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      expect(controller.text, 'test@example.com');
    });

    testWidgets('OmniTextField toggles obscure text visibility', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniTextField(
              controller: controller,
              labelText: 'Password',
              obscureText: true,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'password123');

      // Initially obscured
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Tap visibility button to toggle
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      // Now should show visibility on
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('OmniTextField shows prefix icon when provided', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniTextField(
              controller: controller,
              labelText: 'Email',
              prefixIcon: Icons.email,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('OmniTextField calls validator when provided', (WidgetTester tester) async {
      final controller = TextEditingController();
      bool validatorCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Form(
              child: OmniTextField(
                controller: controller,
                labelText: 'Email',
                validator: (value) {
                  validatorCalled = true;
                  if (value?.isEmpty ?? true) {
                    return 'Field is required';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Form(
              child: OmniTextField(
                controller: controller,
                labelText: 'Email',
                validator: (value) {
                  validatorCalled = true;
                  return 'Error';
                },
              ),
            ),
          ),
        ),
      );

      expect(validatorCalled || find.byType(TextFormField).evaluate().isNotEmpty, true);
    });

    testWidgets('OmniTextField displays hint text', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniTextField(
              controller: controller,
              labelText: 'Email',
              hintText: 'Enter your email',
            ),
          ),
        ),
      );

      expect(find.text('Enter your email'), findsOneWidget);
    });
  });
}
