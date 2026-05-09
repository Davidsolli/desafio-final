import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:omniconnect_fitness/services/notification_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

import 'notification_service_test.mocks.dart';

@GenerateMocks([ApiClient])
void main() {
  group('NotificationService', () {
    late MockApiClient mockApiClient;
    late NotificationService notificationService;

    setUp(() {
      mockApiClient = MockApiClient();
      notificationService = NotificationService(apiClient: mockApiClient);
    });

    test('sendTokenToBackend chama PUT com o token correto', () async {
      const token = 'mock_fcm_token_123';

      when(
        mockApiClient.put<Map<String, dynamic>>(
          '/api/v1/notifications/token',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => {'success': true});

      await notificationService.sendTokenToBackend(token);

      final captured = verify(
        mockApiClient.put<Map<String, dynamic>>(
          '/api/v1/notifications/token',
          body: captureAnyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      )..called(1);

      final sentBody = captured.captured.first as Map<String, dynamic>;
      expect(sentBody['fcm_token'], equals(token));
    });

    test('getPreferences retorna mapa com todas as preferências', () async {
      final mockPrefs = {
        'notifications_enabled': true,
        'workout_reminder_enabled': true,
        'workout_reminder_time': '17:00',
        'meal_reminder_enabled': false,
        'quiet_hours_start': '22:00',
        'quiet_hours_end': '07:00',
        'silent_days': [0, 6],
      };

      when(
        mockApiClient.get<Map<String, dynamic>>(
          '/api/v1/notifications/preferences',
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => mockPrefs);

      final prefs = await notificationService.getPreferences();

      expect(prefs['notifications_enabled'], isTrue);
      expect(prefs['workout_reminder_enabled'], isTrue);
      expect(prefs['quiet_hours_start'], equals('22:00'));
      expect(prefs['silent_days'], equals([0, 6]));
    });

    test('updatePreferences retorna true quando API responde com sucesso',
        () async {
      final updateData = {
        'workout_reminder_time': '18:00',
        'notifications_enabled': false,
      };

      when(
        mockApiClient.put<Map<String, dynamic>>(
          '/api/v1/notifications/preferences',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => updateData);

      final success = await notificationService.updatePreferences(updateData);

      expect(success, isTrue);
      verify(
        mockApiClient.put<Map<String, dynamic>>(
          '/api/v1/notifications/preferences',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);
    });

    test('getPreferences retorna mapa vazio quando a API lança exceção',
        () async {
      when(
        mockApiClient.get<Map<String, dynamic>>(
          '/api/v1/notifications/preferences',
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(Exception('Network error'));

      final prefs = await notificationService.getPreferences();

      expect(prefs.isEmpty, isTrue);
    });

    test('updatePreferences retorna false quando a API lança exceção', () async {
      when(
        mockApiClient.put<Map<String, dynamic>>(
          '/api/v1/notifications/preferences',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(Exception('API error'));

      final success =
          await notificationService.updatePreferences({'notifications_enabled': true});

      expect(success, isFalse);
    });
  });
}
