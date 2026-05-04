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
  final String? gender;
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
    this.gender,
    this.phoneWhatsapp,
    required this.createdAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      age: json['age'] as int? ?? 0,
      gender: json['gender'] as String?,
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

  Future<UserResponse> updateUser({
    required String id,
    required String name,
    required double weight,
    required double height,
    required int age,
    String? gender,
    String? phoneWhatsapp,
  }) async {
    try {
      final response = await _apiClient.put<UserResponse>(
        '/users/$id',
        body: {
          'name': name,
          'weight': weight,
          'height': height,
          'age': age,
          if (gender != null) 'gender': gender,
          if (phoneWhatsapp != null) 'phone_whatsapp': phoneWhatsapp,
        },
        fromJson: (data) => UserResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Lista usuários com paginação e filtro opcional por papel
  ///
  /// Requer que o usuário autenticado seja admin ou personal_trainer.
  Future<List<UserResponse>> listUsers({
    int page = 1,
    int limit = 50,
    String? role,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (role != null) 'role': role,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await _apiClient.get<List<UserResponse>>(
        '/users',
        queryParameters: queryParams,
        fromJson: (data) {
          List<dynamic> items;
          if (data is Map && data.containsKey('data')) {
            items = data['data'] as List<dynamic>;
          } else if (data is List) {
            items = data;
          } else {
            return [];
          }
          return items
              .whereType<Map<String, dynamic>>()
              .map((u) => UserResponse.fromJson(u))
              .toList();
        },
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
