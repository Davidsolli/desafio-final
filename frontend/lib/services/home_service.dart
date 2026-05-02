import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class HomeUserData {
  final String id;
  final String name;
  final double? weight;
  final double? height;
  final int? age;
  final String? gender;

  HomeUserData({
    required this.id,
    required this.name,
    this.weight,
    this.height,
    this.age,
    this.gender,
  });

  factory HomeUserData.fromJson(Map<String, dynamic> json) {
    return HomeUserData(
      id: json['id'] as String,
      name: json['name'] as String,
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      age: json['age'] as int?,
      gender: json['gender'] as String?,
    );
  }

  bool get hasAnthropometry =>
      weight != null && weight! > 0 && height != null && height! > 0;

  double? get imc {
    if (!hasAnthropometry) return null;
    final h = height! / 100;
    return weight! / (h * h);
  }

  String get imcLabel {
    final v = imc;
    if (v == null) return '—';
    if (v < 18.5) return 'Abaixo do peso';
    if (v < 25.0) return 'Normal';
    if (v < 30.0) return 'Sobrepeso';
    if (v < 35.0) return 'Obeso';
    return 'Obeso severo';
  }

  // Harris-Benedict: male uses gender == 'male', everything else uses female formula
  int? get tmb {
    if (!hasAnthropometry || age == null || age! <= 0) return null;
    if (gender == 'male') {
      return (88.362 + (13.397 * weight!) + (4.799 * height!) - (5.677 * age!))
          .toInt();
    }
    return (447.593 + (9.247 * weight!) + (3.098 * height!) - (4.330 * age!))
        .toInt();
  }
}

class HomeGoalData {
  final String id;
  final String title;

  // 0.0–1.0 ready for LinearProgressIndicator
  final double progress;
  final String status;

  HomeGoalData({
    required this.id,
    required this.title,
    required this.progress,
    required this.status,
  });

  factory HomeGoalData.fromJson(Map<String, dynamic> json) {
    final pct = (json['progress_percentage'] as num?)?.toDouble() ?? 0.0;
    return HomeGoalData(
      id: json['id'] as String,
      title: json['title'] as String,
      progress: (pct / 100).clamp(0.0, 1.0),
      status: json['status'] as String? ?? 'active',
    );
  }

  bool get completed => status == 'completed';
}

class HomeExerciseData {
  final String name;
  final String muscleGroup;
  final int series;
  final int restSeconds;

  HomeExerciseData({
    required this.name,
    required this.muscleGroup,
    required this.series,
    required this.restSeconds,
  });

  factory HomeExerciseData.fromJson(Map<String, dynamic> json) {
    return HomeExerciseData(
      name: json['name'] as String? ?? '',
      muscleGroup: json['muscle_group'] as String? ?? '',
      series: json['series'] as int? ?? 3,
      restSeconds: json['rest_seconds'] as int? ?? 60,
    );
  }
}

class HomeWorkoutData {
  final String id;
  final String name;
  final int dayOfWeek;
  final List<HomeExerciseData> exercises;

  HomeWorkoutData({
    required this.id,
    required this.name,
    required this.dayOfWeek,
    required this.exercises,
  });

  factory HomeWorkoutData.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'] as List<dynamic>? ?? [];
    final exercises = rawExercises
        .whereType<Map<String, dynamic>>()
        .map(HomeExerciseData.fromJson)
        .toList();

    return HomeWorkoutData(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Treino',
      dayOfWeek: json['day_of_week'] as int? ?? 0,
      exercises: exercises,
    );
  }

  // Extract "Peito + Tríceps" from "Treino A - Peito + Tríceps", or derive from
  // the first exercise's muscle group as fallback.
  String get label {
    final parts = name.split(' - ');
    if (parts.length > 1) return parts.sublist(1).join(' - ');
    if (exercises.isNotEmpty) {
      return _formatMuscleGroup(exercises.first.muscleGroup);
    }
    return '';
  }

  String get emoji {
    if (exercises.isEmpty) return '🏋️';
    return _emojiForMuscleGroup(exercises.first.muscleGroup);
  }

  // Rough estimate: each set takes ~45 s of work + rest between sets.
  int? get duration {
    if (exercises.isEmpty) return null;
    final totalSeconds = exercises.fold<int>(
      0,
      (sum, ex) => sum + (ex.series * 45) + ((ex.series - 1) * ex.restSeconds),
    );
    return (totalSeconds / 60).ceil().clamp(10, 120);
  }

  static String _emojiForMuscleGroup(String group) {
    switch (group) {
      case 'peito':
        return '💪';
      case 'costa':
        return '🔙';
      case 'perna_anterior':
      case 'perna_posterior':
      case 'panturrilha':
        return '🦵';
      case 'ombro':
        return '🏋️';
      case 'bíceps':
      case 'tríceps':
      case 'antebraço':
        return '💪';
      case 'core':
        return '🔥';
      default:
        return '🏃';
    }
  }

  static String _formatMuscleGroup(String group) {
    const map = {
      'peito': 'Peito',
      'costa': 'Costas',
      'perna_anterior': 'Quadríceps',
      'perna_posterior': 'Posterior',
      'ombro': 'Ombros',
      'bíceps': 'Bíceps',
      'tríceps': 'Tríceps',
      'core': 'Core',
      'panturrilha': 'Panturrilha',
      'antebraço': 'Antebraço',
    };
    return map[group] ?? group;
  }
}

class HomeData {
  final HomeUserData user;
  final List<HomeGoalData> goals;
  final HomeWorkoutData? todayWorkout;

  HomeData({
    required this.user,
    required this.goals,
    this.todayWorkout,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class HomeService {
  final ApiClient _apiClient;

  HomeService({required ApiClient apiClient}) : _apiClient = apiClient;

  // Flutter: weekday 1=Mon … 7=Sun → Backend: 0=Mon … 6=Sun
  int get _todayBackendDay => DateTime.now().weekday - 1;

  Future<HomeData> fetchHomeData() async {
    // User must succeed – propagate any error to the provider.
    final user = await _getUser();

    // Goals and workout-sheet are independent; fetch in parallel.
    // Each catches its own errors and returns a safe fallback.
    final results = await Future.wait([
      _getGoals(),
      _getTodayWorkout(),
    ]);

    return HomeData(
      user: user,
      goals: results[0] as List<HomeGoalData>,
      todayWorkout: results[1] as HomeWorkoutData?,
    );
  }

  Future<HomeUserData> _getUser() async {
    return _apiClient.get<HomeUserData>(
      '/users/me',
      fromJson: (data) =>
          HomeUserData.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<HomeGoalData>> _getGoals() async {
    try {
      return await _apiClient.get<List<HomeGoalData>>(
        '/goals',
        queryParameters: {'status': 'active', 'limit': 2},
        fromJson: (data) {
          final List<dynamic> items;
          if (data is Map && data.containsKey('data')) {
            items = data['data'] as List<dynamic>;
          } else if (data is List) {
            items = data;
          } else {
            return [];
          }
          return items
              .whereType<Map<String, dynamic>>()
              .map(HomeGoalData.fromJson)
              .toList();
        },
      );
    } catch (e) {
      debugPrint('[HomeService] getGoals failed: $e');
      return [];
    }
  }

  Future<HomeWorkoutData?> _getTodayWorkout() async {
    try {
      // Step 1: list sheets for today (no exercises in list response).
      final listResult = await _apiClient.get<Map<String, dynamic>?>(
        '/workout-sheets',
        queryParameters: {
          'day_of_week': _todayBackendDay,
          'limit': 1,
        },
        fromJson: (data) => data is Map<String, dynamic> ? data : null,
      );

      if (listResult == null) return null;

      final items = listResult['data'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      final sheetId =
          (items.first as Map<String, dynamic>)['id'] as String?;
      if (sheetId == null) return null;

      // Step 2: fetch detail with full exercise list.
      return await _apiClient.get<HomeWorkoutData>(
        '/workout-sheets/$sheetId',
        fromJson: (data) =>
            HomeWorkoutData.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[HomeService] getTodayWorkout failed: $e');
      return null;
    }
  }
}
