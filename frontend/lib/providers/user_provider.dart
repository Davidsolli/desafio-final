import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/user_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Provider para gerenciar estado do usuário autenticado
class UserProvider extends ChangeNotifier {
  final UserService _userService;

  UserResponse? _user;
  bool _isLoading = false;
  String? _error;

  UserProvider({required UserService userService}) : _userService = userService;

  // Getters
  UserResponse? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  /// Carrega dados do usuário autenticado
  Future<void> loadUser() async {
    try {
      _setLoading(true);
      _error = null;

      _user = await _userService.getCurrentUser();
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao carregar usuário: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza dados do usuário
  Future<void> updateUser({
    required String name,
    required double weight,
    required double height,
    required int age,
    String? gender,
    String? phoneWhatsapp,
  }) async {
    if (_user == null) {
      _error = 'Usuário não autenticado.';
      notifyListeners();
      return;
    }

    try {
      _setLoading(true);
      _error = null;

      _user = await _userService.updateUser(
        id: _user!.id,
        name: name,
        weight: weight,
        height: height,
        age: age,
        gender: gender,
        phoneWhatsapp: phoneWhatsapp,
      );
      notifyListeners();
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao atualizar usuário: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Limpa dados do usuário
  void clearUser() {
    _user = null;
    _error = null;
    notifyListeners();
  }

  /// Define o estado de carregamento
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Limpa a mensagem de erro
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
