import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service;

  DashboardProvider(this._service);

  List<StudentDashboardData> students = [];
  bool isLoading = false;
  String? error;
  String trainerName = '';

  /// Carrega todos os dados do dashboard
  Future<void> loadDashboard({String? trainerName}) async {
    isLoading = true;
    error = null;
    this.trainerName = trainerName ?? '';
    notifyListeners();

    try {
      print('Carregando dashboard para $trainerName...');
      students = await _service.loadDashboard();
      print('Dashboard carregado com ${students.length} alunos');
      error = null;
    } catch (e) {
      print('Erro ao carregar dashboard: $e');
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
}
