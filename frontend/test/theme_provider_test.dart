import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omniconnect_fitness/theme/theme_provider.dart';

void main() {
  group('ThemeProvider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('init() carrega preferência salva em SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'theme_preference': 'dark'});

      final provider = ThemeProvider();
      await provider.init();

      expect(provider.isDark, isTrue);
      expect(provider.isInitialized, isTrue);
    });

    test('init() usa system theme se nenhuma preferência salva', () async {
      final provider = ThemeProvider();
      await provider.init();

      expect(provider.themeMode, equals(ThemeMode.system));
      expect(provider.isInitialized, isTrue);
    });

    test('toggleTheme() alterna entre light e dark', () async {
      final provider = ThemeProvider();
      await provider.init();

      // Começa em system, muda para dark
      provider.themeMode = ThemeMode.light;
      await provider.toggleTheme();
      expect(provider.isDark, isTrue);

      // Dark para light
      await provider.toggleTheme();
      expect(provider.isDark, isFalse);
    });

    test('toggleTheme() persiste em SharedPreferences', () async {
      final provider = ThemeProvider();
      await provider.init();

      provider.themeMode = ThemeMode.light;
      await provider.toggleTheme();

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('theme_preference');
      expect(saved, equals('dark'));
    });

    test('setTheme() define tema específico', () async {
      final provider = ThemeProvider();
      await provider.init();

      await provider.setTheme(ThemeMode.dark);
      expect(provider.isDark, isTrue);

      await provider.setTheme(ThemeMode.light);
      expect(provider.isDark, isFalse);

      await provider.setTheme(ThemeMode.system);
      expect(provider.themeMode, equals(ThemeMode.system));
    });

    test('setTheme() persiste em SharedPreferences', () async {
      final provider = ThemeProvider();
      await provider.init();

      await provider.setTheme(ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('theme_preference');
      expect(saved, equals('dark'));
    });

    test('isDark retorna true apenas para ThemeMode.dark', () async {
      final provider = ThemeProvider();
      await provider.init();

      provider.themeMode = ThemeMode.dark;
      expect(provider.isDark, isTrue);

      provider.themeMode = ThemeMode.light;
      expect(provider.isDark, isFalse);

      provider.themeMode = ThemeMode.system;
      expect(provider.isDark, isFalse);
    });

    test('notifyListeners() chamado após toggle', () async {
      final provider = ThemeProvider();
      await provider.init();

      var changeCount = 0;
      provider.addListener(() {
        changeCount++;
      });

      provider.themeMode = ThemeMode.light;
      await provider.toggleTheme();

      expect(changeCount, greaterThan(0));
    });

    test('Preferência persiste entre instâncias de provider', () async {
      // Primeira instância
      final provider1 = ThemeProvider();
      await provider1.init();
      await provider1.setTheme(ThemeMode.dark);

      // Segunda instância (simulando reinicialização do app)
      final provider2 = ThemeProvider();
      await provider2.init();

      expect(provider2.themeMode, equals(ThemeMode.dark));
      expect(provider2.isDark, isTrue);
    });
  });
}
