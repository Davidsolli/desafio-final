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
  final String? goalType;
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
    this.goalType,
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
      goalType: json['goal_type'] as String?,
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
    if (gender == 'male') {
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

  /// Busca dados de um usuário específico por ID.
  Future<UserResponse> getUserById(String userId) async {
    try {
      final response = await _apiClient.get<UserResponse>(
        '/users/$userId',
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
    double? weight,
    double? height,
    int? age,
    String? gender,
    String? phoneWhatsapp,
  }) async {
    try {
      final body = {
        'name': name,
        if (weight != null) 'weight': weight,
        if (height != null) 'height': height,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (phoneWhatsapp != null) 'phone_whatsapp': phoneWhatsapp,
      };

      final response = await _apiClient.put<UserResponse>(
        '/users/$id',
        body: body,
        fromJson: (data) => UserResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Busca lista de alunos do personal trainer autenticado
  Future<List<UserResponse>> getStudents({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/users/students?page=$page&limit=$limit',
        fromJson: (data) => data as Map<String, dynamic>,
      );

      final List<dynamic> students = response['data'] as List<dynamic>;
      return students
          .map((student) => UserResponse.fromJson(student as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica se o usuário está autenticado
  bool get isAuthenticated => _apiClient.isAuthenticated;

  /// Retorna o token armazenado
  String? get token => _apiClient.token;
}
