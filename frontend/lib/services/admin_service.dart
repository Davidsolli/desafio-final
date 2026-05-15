import 'api_client.dart';
import '../models/admin_models.dart';

class AdminService {
  final ApiClient _apiClient;

  AdminService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<AdminUserDTO>> listTrainers() async {
    const limit = 100;
    try {
      Future<List<AdminUserDTO>> fetchAll(String role) async {
        final all = <AdminUserDTO>[];
        int p = 1;
        while (true) {
          final response = await _apiClient.get<PaginatedAdminUsersDTO>(
            '/users?role=$role&page=$p&limit=$limit&include_inactive=true',
            fromJson: (json) => PaginatedAdminUsersDTO.fromJson(json as Map<String, dynamic>),
          );
          all.addAll(response.data);
          if (all.length >= response.total || response.data.isEmpty) break;
          p++;
        }
        return all;
      }

      final results = await Future.wait([fetchAll('personal_trainer'), fetchAll('nutritionist')]);
      // Remove duplicatas (profissionais duais aparecem nas duas listas)
      final combined = <String, AdminUserDTO>{};
      for (final list in results) {
        for (final user in list) {
          combined[user.id] = user;
        }
      }
      final result = combined.values.toList();
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AdminUserDTO>> listAllStudents() async {
    const limit = 100;
    final all = <AdminUserDTO>[];
    int page = 1;
    try {
      while (true) {
        final response = await _apiClient.get<PaginatedAdminUsersDTO>(
          '/users?role=client&page=$page&limit=$limit&include_inactive=true',
          fromJson: (json) => PaginatedAdminUsersDTO.fromJson(json as Map<String, dynamic>),
        );
        all.addAll(response.data);
        if (all.length >= response.total || response.data.isEmpty) break;
        page++;
      }
      return all;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AdminUserDTO>> listStudentsOfTrainer(
    String trainerId, {
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.get<PaginatedAdminUsersDTO>(
        '/users?trainer_id=$trainerId&page=$page&limit=$limit&include_inactive=true',
        fromJson: (json) => PaginatedAdminUsersDTO.fromJson(json as Map<String, dynamic>),
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<AdminUserDTO> createTrainer(CreateTrainerDTO dto) async {
    try {
      return await _apiClient.post<AdminUserDTO>(
        '/users',
        body: dto.toJson(),
        fromJson: (json) => AdminUserDTO.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<AdminUserDTO> updateUser(String userId, UpdateAdminUserDTO dto) async {
    try {
      return await _apiClient.put<AdminUserDTO>(
        '/users/$userId',
        body: dto.toJson(),
        fromJson: (json) => AdminUserDTO.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<AdminUserDTO> toggleStatus(String userId, bool currentIsActive) async {
    try {
      final dto = UpdateAdminUserDTO(isActive: !currentIsActive);
      return await updateUser(userId, dto);
    } catch (e) {
      rethrow;
    }
  }

  Future<AdminUserDTO> getMe() async {
    try {
      return await _apiClient.get<AdminUserDTO>(
        '/users/me',
        fromJson: (json) => AdminUserDTO.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<AdminUserDTO> updateMe(String userId, UpdateAdminUserDTO dto) async {
    try {
      return await updateUser(userId, dto);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _apiClient.put<Map<String, dynamic>>(
        '/users/$userId/password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
        fromJson: (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      rethrow;
    }
  }
}
