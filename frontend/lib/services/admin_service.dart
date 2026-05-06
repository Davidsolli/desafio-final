import 'api_client.dart';
import '../models/admin_models.dart';

class AdminService {
  final ApiClient _apiClient;

  AdminService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<AdminUserDTO>> listTrainers({int page = 1, int limit = 100}) async {
    try {
      final response = await _apiClient.get<PaginatedAdminUsersDTO>(
        '/users?role=personal_trainer&page=$page&limit=$limit&include_inactive=true',
        fromJson: (json) => PaginatedAdminUsersDTO.fromJson(json as Map<String, dynamic>),
      );
      return response.data;
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
}
