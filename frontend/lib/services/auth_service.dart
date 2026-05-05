import 'package:omniconnect_fitness/services/api_client.dart';

/// Modelo de resposta de login
class LoginResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 86400,
    );
  }
}

/// Modelo de resposta de usuário
class UserResponse {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phoneWhatsapp;
  final DateTime createdAt;

  UserResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneWhatsapp,
    required this.createdAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      phoneWhatsapp: json['phone_whatsapp'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toString()),
    );
  }
}

/// Serviço de autenticação
///
/// Responsável por:
/// - Login de usuários
/// - Registro de novos usuários
/// - Logout (limpeza de token)
/// - Armazenamento seguro de token
class AuthService {
  final ApiClient _apiClient;

  AuthService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Faz login com email e senha
  ///
  /// Args:
  ///   email: Email do usuário
  ///   password: Senha do usuário
  ///
  /// Returns:
  ///   LoginResponse com access_token
  ///
  /// Throws:
  ///   UnauthorizedException se credenciais inválidas
  ///   NetworkException se erro de conexão
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<LoginResponse>(
        '/auth/login',
        body: {
          'email': email,
          'password': password,
        },
        fromJson: (data) => LoginResponse.fromJson(data as Map<String, dynamic>),
      );

      // Salva o token
      await _apiClient.saveToken(response.accessToken);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Registra um novo usuário
  ///
  /// Args:
  ///   name: Nome do usuário
  ///   email: Email do usuário
  ///   password: Senha do usuário
  ///   role: Papel do usuário (client, personal_trainer, admin)
  ///   phoneWhatsapp: Número WhatsApp (opcional)
  ///   invitationCode: Código de convite (obrigatório para clientes, opcional para PTs)
  ///
  /// Returns:
  ///   UserResponse com dados do usuário criado
  ///
  /// Throws:
  ///   ApiException se erro
  ///   NetworkException se erro de conexão
  Future<UserResponse> register({
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
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      };
      if (phoneWhatsapp != null) body['phone_whatsapp'] = phoneWhatsapp;
      if (weightKg != null) body['weight_kg'] = weightKg;
      if (heightCm != null) body['height_cm'] = heightCm;
      if (age != null) body['age'] = age;
      if (goalType != null) body['goal_type'] = goalType;
      if (invitationCode != null) body['invitation_code'] = invitationCode;

      final response = await _apiClient.post<UserResponse>(
        '/users',
        body: body,
        fromJson: (data) => UserResponse.fromJson(data as Map<String, dynamic>),
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Faz logout limpando o token
  Future<void> logout() async {
    await _apiClient.clearToken();
  }

  /// Verifica se o usuário está autenticado
  bool get isAuthenticated => _apiClient.isAuthenticated;

  /// Retorna o token armazenado
  String? get token => _apiClient.token;
}
