import 'package:omniconnect_fitness/services/api_client.dart';

/// Modelo de resposta de usuário
class UserResponse {
  final String id;
  final String name;
  final String email;
  final String role;
  final double weight;
  final double height;
  final int age;
  final String? phoneWhatsapp;
  final DateTime createdAt;

  UserResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.weight,
    required this.height,
    required this.age,
    this.phoneWhatsapp,
    required this.createdAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      weight: (json['weight'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      age: json['age'] as int,
      phoneWhatsapp: json['phone_whatsapp'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toString()),
    );
  }

  double get imc => weight / ((height / 100) * (height / 100));

  String get imcLabel {
    if (imc < 18.5) return 'Abaixo do peso';
    if (imc < 25) return 'Normal';
    if (imc < 30) return 'Sobrepeso';
    if (imc < 35) return 'Obeso';
    return 'Obeso severo';
  }

  int get tmb {
    if (role == 'male') {
      return (88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age)).toInt();
    } else {
      return (447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age)).toInt();
    }
  }

  int get tdee => (tmb * 1.5).toInt();
}

/// Serviço de usuário
class UserService {
  final ApiClient _apiClient;

  UserService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Busca dados do usuário autenticado
  Future<UserResponse> getCurrentUser() async {
    try {
      final response = await _apiClient.get<UserResponse>(
        '/users/me',
        fromJson: (data) => UserResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Atualiza dados do usuário
  Future<UserResponse> updateUser({
    required String name,
    required double weight,
    required double height,
    required int age,
    String? phoneWhatsapp,
  }) async {
    try {
      final response = await _apiClient.put<UserResponse>(
        '/users/me',
        body: {
          'name': name,
          'weight': weight,
          'height': height,
          'age': age,
          'phone_whatsapp': phoneWhatsapp,
        },
        fromJson: (data) => UserResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica se o usuário está autenticado
  bool get isAuthenticated => _apiClient.isAuthenticated;

  /// Retorna o token armazenado
  String? get token => _apiClient.token;
}
