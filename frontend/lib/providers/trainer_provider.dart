import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/user_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Provider para gerenciar o estado do painel profissional (trainer/personal).
///
/// Carrega a lista de alunos (role=client) e estatísticas do dashboard.
class TrainerProvider extends ChangeNotifier {
  final UserService _userService;

  List<UserResponse> _students = [];
  List<UserResponse> _filteredStudents = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  TrainerProvider({required UserService userService})
      : _userService = userService;

  // Getters
  List<UserResponse> get students => _students;
  List<UserResponse> get filteredStudents => _filteredStudents;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasStudents => _students.isNotEmpty;
  int get activeCount => _students.length;

  /// Carrega a lista de alunos (usuários com role=client)
  Future<void> loadStudents() async {
    try {
      _setLoading(true);
      _error = null;

      final result = await _userService.listUsers(
        page: 1,
        limit: 100,
        role: 'client',
      );

      _students = result;
      _applyFilter();
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
      _error = 'Erro ao carregar alunos: ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Filtra alunos pelo nome
  void filterBySearch(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredStudents = List.from(_students);
    } else {
      _filteredStudents = _students
          .where((s) => s.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearAll() {
    _students = [];
    _filteredStudents = [];
    _error = null;
    notifyListeners();
  }
}
