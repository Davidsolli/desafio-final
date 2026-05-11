// ignore_for_file: type=lint
import 'package:mockito/mockito.dart';
import 'package:omniconnect_fitness/services/notification_service.dart';

/// Fake estável de NotificationService para testes de UI.
///
/// Por que não usar `@GenerateMocks([NotificationService])` direto: Mockito
/// resolve `notification_service.dart` (conditional export) contra o stub no
/// build_runner deste projeto, mas em desktop o tipo `NotificationService`
/// resolve para o mobile — gerando incompatibilidade de tipos no Provider.
/// Esta Fake estende o tipo público real e cobre apenas os métodos usados
/// nos testes de tela.
class FakeNotificationService extends Fake implements NotificationService {
  // ---- inputs configuráveis ----
  Map<String, dynamic> preferencesToReturn = const {};
  Future<Map<String, dynamic>> Function()? preferencesFuture;
  bool throwOnHistory = false;
  List<Map<String, dynamic>> historyToReturn = const [];
  bool updateOk = true;
  bool markReadOk = true;

  // ---- captura ----
  final List<Map<String, dynamic>> updateCalls = [];
  final List<String> markReadIds = [];
  int historyCallCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> sendTokenToBackend(String token) async {}

  @override
  Future<Map<String, dynamic>> getPreferences() async {
    if (preferencesFuture != null) {
      return preferencesFuture!();
    }
    return preferencesToReturn;
  }

  @override
  Future<bool> updatePreferences(Map<String, dynamic> data) async {
    updateCalls.add(data);
    return updateOk;
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory({String? type, int limit = 20}) async {
    historyCallCount += 1;
    if (throwOnHistory) {
      throw Exception('boom');
    }
    return historyToReturn;
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    markReadIds.add(notificationId);
    return markReadOk;
  }
}
