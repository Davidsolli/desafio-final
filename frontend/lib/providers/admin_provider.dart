import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../models/admin_models.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _service;

  List<AdminUserDTO> _trainers = [];
  List<AdminUserDTO> _studentsOfTrainer = [];
  AdminUserDTO? _currentAdmin;
  bool _isLoading = false;
  String? _error;
  String? _currentTrainerId;

  AdminProvider({required AdminService service}) : _service = service;

  // Getters públicos
  List<AdminUserDTO> get trainers => _trainers;
  List<AdminUserDTO> get studentsOfTrainer => _studentsOfTrainer;
  AdminUserDTO? get currentAdmin => _currentAdmin;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentTrainerId => _currentTrainerId;

  Future<void> loadTrainers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _trainers = await _service.listTrainers();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStudentsOfTrainer(String trainerId) async {
    _isLoading = true;
    _error = null;
    _currentTrainerId = trainerId;
    notifyListeners();
    try {
      _studentsOfTrainer = await _service.listStudentsOfTrainer(trainerId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTrainer(CreateTrainerDTO dto) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final newTrainer = await _service.createTrainer(dto);
      _trainers.add(newTrainer);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleUserStatus(String userId, bool currentIsActive) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.toggleStatus(userId, currentIsActive);

      // Atualizar na lista apropriada
      final trainerIndex = _trainers.indexWhere((t) => t.id == userId);
      if (trainerIndex != -1) {
        _trainers[trainerIndex] = updated;
        notifyListeners();
      }

      final studentIndex = _studentsOfTrainer.indexWhere((s) => s.id == userId);
      if (studentIndex != -1) {
        _studentsOfTrainer[studentIndex] = updated;
        notifyListeners();
      }

      if (_currentAdmin?.id == userId) {
        _currentAdmin = updated;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTrainer(String trainerId, UpdateAdminUserDTO dto) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.updateUser(trainerId, dto);
      final index = _trainers.indexWhere((t) => t.id == trainerId);
      if (index != -1) {
        _trainers[index] = updated;
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStudent(String studentId, UpdateAdminUserDTO dto) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.updateUser(studentId, dto);
      final index = _studentsOfTrainer.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        _studentsOfTrainer[index] = updated;
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMe() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _currentAdmin = await _service.getMe();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateMe(String userId, UpdateAdminUserDTO dto) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.updateMe(userId, dto);
      _currentAdmin = updated;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int getStudentCountForTrainer(String trainerId) {
    return _trainers
        .firstWhere((t) => t.id == trainerId)
        .id
        .length; // placeholder, será preenchido depois
  }
}
