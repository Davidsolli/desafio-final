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
          '/notifications/token',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => {'success': true});

      await notificationService.sendTokenToBackend(token);

      final captured = verify(
        mockApiClient.put<Map<String, dynamic>>(
          '/notifications/token',
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
          '/notifications/preferences',
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
          '/notifications/preferences',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => updateData);

      final success = await notificationService.updatePreferences(updateData);

      expect(success, isTrue);
      verify(
        mockApiClient.put<Map<String, dynamic>>(
          '/notifications/preferences',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).called(1);
    });

    test('getPreferences retorna mapa vazio quando a API lança exceção',
        () async {
      when(
        mockApiClient.get<Map<String, dynamic>>(
          '/notifications/preferences',
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(Exception('Network error'));

      final prefs = await notificationService.getPreferences();

      expect(prefs.isEmpty, isTrue);
    });

    test('updatePreferences retorna false quando a API lança exceção', () async {
      when(
        mockApiClient.put<Map<String, dynamic>>(
          '/notifications/preferences',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(Exception('API error'));

      final success =
          await notificationService.updatePreferences({'notifications_enabled': true});

      expect(success, isFalse);
    });

    // ----- Fase 1: getHistory + markAsRead -----

    test('getHistory chama GET /history e retorna lista de notificações',
        () async {
      final mockResponse = {
        'total': 2,
        'data': [
          {
            'id': 'n1',
            'notification_type': 'workout_reminder',
            'title': 'Hora do treino',
            'body': 'Treino A',
            'created_at': '2026-05-08T10:00:00Z',
            'read_at': null,
          },
          {
            'id': 'n2',
            'notification_type': 'achievement',
            'title': 'Meta concluída',
            'body': 'Parabéns!',
            'created_at': '2026-05-07T18:30:00Z',
            'read_at': '2026-05-07T19:00:00Z',
          },
        ],
      };

      when(
        mockApiClient.get<Map<String, dynamic>>(
          '/notifications/history',
          queryParameters: anyNamed('queryParameters'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => mockResponse);

      final history = await notificationService.getHistory();

      expect(history, isA<List<Map<String, dynamic>>>());
      expect(history.length, equals(2));
      expect(history[0]['title'], equals('Hora do treino'));
      expect(history[1]['read_at'], isNotNull);
    });

    test('getHistory retorna lista vazia quando a API lança', () async {
      when(
        mockApiClient.get<Map<String, dynamic>>(
          '/notifications/history',
          queryParameters: anyNamed('queryParameters'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(Exception('Network error'));

      final history = await notificationService.getHistory();

      expect(history, isEmpty);
    });

    test('markAsRead chama POST /mark-read e retorna true em sucesso',
        () async {
      const notificationId = 'abc-123';

      when(
        mockApiClient.post<Map<String, dynamic>>(
          '/notifications/mark-read',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenAnswer((_) async => {'status': 'success'});

      final ok = await notificationService.markAsRead(notificationId);

      expect(ok, isTrue);
      final captured = verify(
        mockApiClient.post<Map<String, dynamic>>(
          '/notifications/mark-read',
          body: captureAnyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      )..called(1);
      final sent = captured.captured.first as Map<String, dynamic>;
      expect(sent['notification_id'], equals(notificationId));
    });

    test('markAsRead retorna false quando API lança', () async {
      when(
        mockApiClient.post<Map<String, dynamic>>(
          '/notifications/mark-read',
          body: anyNamed('body'),
          fromJson: anyNamed('fromJson'),
        ),
      ).thenThrow(Exception('500'));

      final ok = await notificationService.markAsRead('xyz');
      expect(ok, isFalse);
    });
  });
}
