List<String> parseRoles(String role) =>
    role.split(',').map((r) => r.trim()).where((r) => r.isNotEmpty).toList();

bool hasRole(String role, String target) => parseRoles(role).contains(target);

class AdminUserDTO {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phoneWhatsapp;
  final String? trainerId;
  final bool isActive;
  final DateTime createdAt;

  AdminUserDTO({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneWhatsapp,
    this.trainerId,
    required this.isActive,
    required this.createdAt,
  });

  factory AdminUserDTO.fromJson(Map<String, dynamic> json) {
    return AdminUserDTO(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      phoneWhatsapp: json['phone_whatsapp'] as String?,
      trainerId: json['trainer_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'phone_whatsapp': phoneWhatsapp,
    'trainer_id': trainerId,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };

  List<String> get specialties {
    return parseRoles(role)
        .where((r) => r == 'personal_trainer' || r == 'nutritionist')
        .toList();
  }

  String get specialtyLabel {
    final s = specialties;
    final isPersonal = s.contains('personal_trainer');
    final isNutri = s.contains('nutritionist');
    if (isPersonal && isNutri) return 'Personal + Nutricionista';
    if (isNutri) return 'Nutricionista';
    return 'Personal Trainer';
  }
}

class CreateTrainerDTO {
  final String name;
  final String email;
  final String password;
  final String? phoneWhatsapp;
  final List<String> specialties;

  CreateTrainerDTO({
    required this.name,
    required this.email,
    required this.password,
    this.phoneWhatsapp,
    this.specialties = const ['personal_trainer'],
  });

  Map<String, dynamic> toJson() {
    final sorted = specialties.toSet().toList()..sort();
    return {
      'name': name,
      'email': email,
      'password': password,
      'role': sorted.join(','),
      if (phoneWhatsapp != null) 'phone_whatsapp': phoneWhatsapp,
    };
  }
}

class UpdateAdminUserDTO {
  final String? name;
  final String? phoneWhatsapp;
  final bool? isActive;
  final String? role;
  final String? trainerId;

  UpdateAdminUserDTO({
    this.name,
    this.phoneWhatsapp,
    this.isActive,
    this.role,
    this.trainerId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (phoneWhatsapp != null) map['phone_whatsapp'] = phoneWhatsapp;
    if (isActive != null) map['is_active'] = isActive;
    if (role != null) map['role'] = role;
    if (trainerId != null) map['trainer_id'] = trainerId;
    return map;
  }
}

class PaginatedAdminUsersDTO {
  final int total;
  final int page;
  final int limit;
  final List<AdminUserDTO> data;

  PaginatedAdminUsersDTO({
    required this.total,
    required this.page,
    required this.limit,
    required this.data,
  });

  factory PaginatedAdminUsersDTO.fromJson(Map<String, dynamic> json) {
    return PaginatedAdminUsersDTO(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      data: (json['data'] as List)
          .map((item) => AdminUserDTO.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
