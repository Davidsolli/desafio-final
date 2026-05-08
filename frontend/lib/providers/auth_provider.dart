import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/auth_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Modelo de usuário autenticado
class AuthUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phoneWhatsapp;

  AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneWhatsapp,
  });

  factory AuthUser.fromUserResponse(UserResponse response) {
    return AuthUser(
      id: response.id,
      name: response.name,
      email: response.email,
      role: response.role,
      phoneWhatsapp: response.phoneWhatsapp,
    );
  }
}

/// Provider de autenticação
///
/// Gerencia:
/// - Estado de autenticação
/// - Token JWT
/// - Dados do usuário autenticado
/// - Login/Logout
///
/// Expõe:
/// - isAuthenticated: bool
/// - user: AuthUser?
/// - token: String?
/// - login(email, password)
/// - register(...)
/// - logout()
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthUser? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  AuthProvider({required AuthService authService}) : _authService = authService;

  // Getters
  AuthUser? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Faz login do usuário
  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final response = await _authService.login(
        email: email,
        password: password,
      );

      _token = response.accessToken;

      // Busca o perfil do usuário para obter o role
      final userResponse = await _authService.getCurrentUser();
      _user = AuthUser.fromUserResponse(userResponse);

      notifyListeners();
    } on UnauthorizedException catch (e) {

      _error = e.message;
      _token = null;
      _user = null;
      notifyListeners();
      rethrow;
    } on NetworkException catch (e) {
      _error = 'Erro de conexão: ${e.message}';
      notifyListeners();
      rethrow;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Erro ao fazer login: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Verifica o estado de autenticação silenciosamente (chamado no startup)
  Future<void> checkAuthState() async {
    try {
      _setLoading(true);
      if (_authService.isAuthenticated) {
        _token = _authService.token;
        final userResponse = await _authService.getCurrentUser();
        _user = AuthUser.fromUserResponse(userResponse);
      } else {
        _token = null;
        _user = null;
      }
    } catch (e) {
      // Se o token for inválido, expirado ou houver erro de rede, limpa a sessão
      _token = null;
      _user = null;
      await _authService.logout();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Registra um novo usuário
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phoneWhatsapp,
    double? weightKg,
    double? heightCm,
    int? age,
    String? goalType,
    String? invitationCode,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final response = await _authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
        phoneWhatsapp: phoneWhatsapp,
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        goalType: goalType,
        invitationCode: invitationCode,
      );

      _user = AuthUser.fromUserResponse(response);
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
      _error = 'Erro ao registrar: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Faz logout do usuário
  Future<void> logout() async {
    try {
      _setLoading(true);
      await _authService.logout();
      _user = null;
      _token = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao fazer logout: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
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

  /// Sincroniza dados do usuário após atualização (sem fazer nova chamada de rede)
  /// Útil após UserProvider.updateUser para manter AuthUser sincronizado
  void updateUserProfile({required String name, String? phoneWhatsapp}) {
    if (_user != null) {
      _user = AuthUser(
        id: _user!.id,
        name: name,
        email: _user!.email,
        role: _user!.role,
        phoneWhatsapp: phoneWhatsapp,
      );
      notifyListeners();
    }
  }

  /// Inicia recuperação de senha
  Future<void> forgotPassword({required String email}) async {
    try {
      _setLoading(true);
      _error = null;

      await _authService.forgotPassword(email: email);
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
      _error = 'Erro ao solicitar recuperação: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Redefine senha com token
  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      await _authService.resetPassword(
        token: token,
        newPassword: password,
        confirmPassword: confirmPassword,
      );

      // Limpar dados após sucesso (usuário deve fazer login novamente)
      _user = null;
      _token = null;

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
      _error = 'Erro ao redefinir senha: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Troca senha para usuário autenticado
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      // Limpar dados após sucesso (usuário será desconectado)
      _user = null;
      _token = null;
      await _authService.logout();

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
      _error = 'Erro ao alterar senha: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
