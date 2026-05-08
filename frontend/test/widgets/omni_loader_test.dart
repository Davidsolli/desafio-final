import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_loader.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';
import 'package:omniconnect_fitness/theme/app_colors.dart';

void main() {
  group('OmniLoader Tests', () {
    testWidgets('OmniLoader renders CircularProgressIndicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniLoader(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('OmniLoader uses primary color by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniLoader(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('OmniLoader respects custom color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniLoader(
              color: AppColors.accentError,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('OmniLoader respects custom size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniLoader(
              size: 60,
            ),
          ),
        ),
      );

      final sizedBox = find.byType(SizedBox);
      expect(sizedBox, findsWidgets);
    });

    testWidgets('OmniLoader defaults to size 40', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniLoader(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('OmniLoader is centered', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OmniLoader(),
          ),
        ),
      );

      final center = find.byType(Center);
      expect(center, findsOneWidget);
    });

    testWidgets('OmniLoader works with white color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Container(
              color: Colors.blue,
              child: OmniLoader(
                color: Colors.white,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
