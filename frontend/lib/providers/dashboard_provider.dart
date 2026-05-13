import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service;

  DashboardProvider(this._service);

  List<StudentDashboardData> students = [];
  bool isLoading = false;
  String? error;
  String trainerName = '';
  int pendingInvites = 0;
  int workoutsThisWeek = 0;

  /// Carrega todos os dados do dashboard
  Future<void> loadDashboard({String? trainerName}) async {
    isLoading = true;
    error = null;
    this.trainerName = trainerName ?? '';
    notifyListeners();

    try {
      // Inicia alunos e convites em paralelo
      final studentsFuture = _service.loadDashboard();
      final invitesFuture = _service.getPendingInvites();

      students = await studentsFuture;
      pendingInvites = await invitesFuture;

      // Calcula treinos desta semana somando os de cada aluno
      workoutsThisWeek = await _service.getStudentsWorkoutsThisWeek(
        students.map((s) => s.id).toList(),
      );
      error = null;
    } catch (e) {
      error = 'Erro ao carregar dashboard: ${e.toString()}';
      students = [];
    }

    isLoading = false;
    notifyListeners();
  }

  /// Contadores agregados
  int get totalStudents => students.length;

  double get averageFrequency {
    if (students.isEmpty) return 0;
    final sum = students.fold<int>(0, (prev, s) => prev + s.weeklyFrequency);
    return sum / students.length;
  }

  double get averageAdherence {
    if (students.isEmpty) return 0;
    final sum = students.fold<double>(0, (prev, s) => prev + s.adherencePercent);
    return sum / students.length;
  }

  /// Alunos ordenados por adesão (descendente)
  List<StudentDashboardData> get studentsSortedByAdherence {
    final sorted = List<StudentDashboardData>.from(students);
    sorted.sort((a, b) => b.adherencePercent.compareTo(a.adherencePercent));
    return sorted;
  }

  /// Alunos inativos: sem treino registrado há 7+ dias ou nunca treinaram
  List<StudentDashboardData> get studentsNeedingAttention {
    final threshold = DateTime.now().subtract(const Duration(days: 7));
    return students.where((s) {
      if (s.lastWorkout == null) return true;
      return s.lastWorkout!.isBefore(threshold);
    }).toList();
  }
}
