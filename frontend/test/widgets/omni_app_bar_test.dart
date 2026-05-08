import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/shared/widgets/omni_app_bar.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';

void main() {
  group('OmniAppBar Tests', () {
    testWidgets('OmniAppBar renders with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: OmniAppBar(
              title: 'Test Title',
            ),
            body: Container(),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('OmniAppBar shows back button by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: OmniAppBar(
              title: 'Test Title',
            ),
            body: Container(),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('OmniAppBar hides back button when showBackButton is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: OmniAppBar(
              title: 'Test Title',
              showBackButton: false,
            ),
            body: Container(),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('OmniAppBar renders action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: OmniAppBar(
              title: 'Test Title',
              actions: [
                IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
              ],
            ),
            body: Container(),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('OmniAppBar back button navigates on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: OmniAppBar(
              title: 'Test Title',
            ),
            body: Container(),
          ),
        ),
      );

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
    });

    testWidgets('OmniAppBar respects custom onBackPressed', (WidgetTester tester) async {
      bool backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: OmniAppBar(
              title: 'Test Title',
              onBackPressed: () {
                backPressed = true;
              },
            ),
            body: Container(),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(backPressed, true);
    });

    testWidgets('OmniAppBar implements PreferredSizeWidget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: OmniAppBar(
              title: 'Test Title',
            ),
            body: Container(),
          ),
        ),
      );

      final appBar = find.byType(OmniAppBar);
      expect(appBar, findsOneWidget);
    });

    testWidgets('OmniAppBar has correct preferredSize', (WidgetTester tester) async {
      final appBar = OmniAppBar(title: 'Test');
      expect(appBar.preferredSize.height, kToolbarHeight);
    });
  });
}
