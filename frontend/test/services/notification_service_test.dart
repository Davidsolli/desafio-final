import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:omniconnect_fitness/services/notification_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

// Mock classes
class MockApiClient extends Mock implements ApiClient {}

void main() {
  group('NotificationService', () {
    late MockApiClient mockApiClient;
    late NotificationService notificationService;

    setUp(() {
      mockApiClient = MockApiClient();
      notificationService = NotificationService(apiClient: mockApiClient);
    });

    testWidgets('test_enviar_token_fcm_ao_backend', (WidgetTester tester) async {
      // Teste: Enviar token FCM ao backend
      const token = 'mock_fcm_token_123';

      // Mock da chamada de API
      when(
        mockApiClient.put<Map<String, dynamic>>(
          '/api/v1/notifications/token',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => {'success': true});

      // Executar
      await notificationService.sendTokenToBackend(token);

      // Verificar se foi chamado
      verify(
        mockApiClient.put<Map<String, dynamic>>(
          '/api/v1/notifications/token',
          body: anything,
          fromJson: anything,
        ),
      ).called(1);
    });

    testWidgets('test_carregar_preferencias_notificacao',
        (WidgetTester tester) async {
      // Teste: Carregar preferências de notificação
      final mockPrefs = {
        'notifications_enabled': true,
        'workout_reminder_enabled': true,
        'workout_reminder_time': '17:00',
        'meal_reminder_enabled': false,
        'quiet_hours_start': '22:00',
        'quiet_hours_end': '07:00',
        'silent_days': [0, 6],
      };

      // Mock da chamada
      when(
        mockApiClient.get<Map<String, dynamic>>(
          '/api/v1/notifications/preferences',
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => mockPrefs);

      // Executar
      final prefs = await notificationService.getPreferences();

      // Verificar
      expect(prefs['notifications_enabled'], isTrue);
      expect(prefs['workout_reminder_enabled'], isTrue);
      expect(prefs['quiet_hours_start'], equals('22:00'));
      expect(prefs['silent_days'], equals([0, 6]));
    });

    testWidgets('test_atualizar_preferencias_notificacao',
        (WidgetTester tester) async {
      // Teste: Atualizar preferências
      final updateData = {
        'workout_reminder_time': '18:00',
        'notifications_enabled': false,
      };

      // Mock da chamada
      when(
        mockApiClient.put<Map<String, dynamic>>(
          '/api/v1/notifications/preferences',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => updateData);

      // Executar
      final success = await notificationService.updatePreferences(updateData);

      // Verificar
      expect(success, isTrue);
      verify(
        mockApiClient.put<Map<String, dynamic>>(
          '/api/v1/notifications/preferences',
          body: anything,
          fromJson: anything,
        ),
      ).called(1);
    });

    testWidgets('test_preferencias_invalidas_retorna_vazio',
        (WidgetTester tester) async {
      // Teste: Chamada com erro retorna mapa vazio
      when(
        mockApiClient.get<Map<String, dynamic>>(
          '/api/v1/notifications/preferences',
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(Exception('Network error'));

      // Executar
      final prefs = await notificationService.getPreferences();

      // Verificar - retorna vazio em caso de erro
      expect(prefs.isEmpty, isTrue);
    });

    testWidgets('test_atualizar_preferencias_com_erro_retorna_falso',
        (WidgetTester tester) async {
      // Teste: Atualizar com erro retorna false
      final updateData = {'notifications_enabled': true};

      when(
        mockApiClient.put<Map<String, dynamic>>(
          '/api/v1/notifications/preferences',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(Exception('API error'));

      // Executar
      final success = await notificationService.updatePreferences(updateData);

      // Verificar
      expect(success, isFalse);
    });
  });
}
