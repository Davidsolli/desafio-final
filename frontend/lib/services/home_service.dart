import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class HomeUserSummary {
  final String id;
  final String name;
  final double? weight;
  final double? height;
  final int? age;
  final String? gender;

  HomeUserSummary({
    required this.id,
    required this.name,
    required this.weight,
    required this.height,
    required this.age,
    this.gender,
  });

  factory HomeUserSummary.fromJson(Map<String, dynamic> json) {
    return HomeUserSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
    );
  }
}

class HomeGoal {
  final String id;
  final String title;
  final double targetValue;
  final double currentValue;
  final String unit;
  final String status;

  HomeGoal({
    required this.id,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.status,
  });

  factory HomeGoal.fromJson(Map<String, dynamic> json) {
    return HomeGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      targetValue: (json['target_value'] as num?)?.toDouble() ?? 0.0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String,
      status: json['status'] as String,
    );
  }

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
}

class HomeExercise {
  final String id;
  final String name;
  final String muscleGroup;
  final int series;
  final int repetitions;
  final double loadKg;
  final int restSeconds;
  final int order;

  HomeExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.series,
    required this.repetitions,
    required this.loadKg,
    required this.restSeconds,
    required this.order,
  });

  factory HomeExercise.fromJson(Map<String, dynamic> json) {
    return HomeExercise(
      id: json['id'].toString(),
      name: json['name'] as String,
      muscleGroup: (json['muscle_group'] as String?) ?? '',
      series: (json['series'] as num?)?.toInt() ?? 1,
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 1,
      loadKg: (json['load_kg'] as num?)?.toDouble() ?? 0.0,
      restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 60,
      order: (json['order'] as num?)?.toInt() ?? 1,
    );
  }
}

class HomeWorkout {
  final String id;
  final String name;
  final String? description;
  final int dayOfWeek;
  final List<HomeExercise> exercises;

  HomeWorkout({
    required this.id,
    required this.name,
    this.description,
    required this.dayOfWeek,
    required this.exercises,
  });

  String get primaryMuscleGroup =>
      exercises.isNotEmpty ? exercises.first.muscleGroup : '';

  String get emoji => muscleGroupEmoji(primaryMuscleGroup);

  String get label {
    final groups = exercises
        .map((e) => muscleGroupLabel(e.muscleGroup))
        .toSet()
        .take(2)
        .join(' + ');
    return groups.isEmpty ? 'Treino' : groups;
  }

  int get estimatedDurationMinutes => estimateWorkoutDuration(exercises);
}

class HomeMetrics {
  final double imc;
  final String imcLabel;
  final int tmb;
  // TODO: replace with real API value when /metrics endpoint becomes available
  final int? weeklyWorkouts;

  const HomeMetrics({
    required this.imc,
    required this.imcLabel,
    required this.tmb,
    this.weeklyWorkouts,
  });

  static const HomeMetrics fallback = HomeMetrics(
    imc: 0.0,
    imcLabel: '—',
    tmb: 0,
    weeklyWorkouts: null,
  );

  String get imcDisplay => imc > 0 ? imc.toStringAsFixed(1) : '—';
  String get tmbDisplay => tmb > 0 ? '$tmb' : '—';
  // null = endpoint not yet available; show '—' instead of a misleading '0'
  String get weeklyWorkoutsDisplay => weeklyWorkouts != null ? '$weeklyWorkouts' : '—';
}

class HomeData {
  final HomeUserSummary user;
  final List<HomeGoal> goals;
  final HomeWorkout? todayWorkout;
  final HomeMetrics metrics;

  const HomeData({
    required this.user,
    required this.goals,
    this.todayWorkout,
    required this.metrics,
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String muscleGroupEmoji(String muscleGroup) {
  switch (muscleGroup) {
    case 'peito':
      return '💪';
    case 'costa':
      return '🔙';
    case 'ombro':
      return '🏋️';
    case 'bíceps':
    case 'tríceps':
    case 'antebraço':
      return '💪';
    case 'core':
      return '🎯';
    case 'perna_anterior':
    case 'perna_posterior':
      return '🦵';
    case 'panturrilha':
      return '🦶';
    default:
      return '🏋️';
  }
}

String muscleGroupLabel(String muscleGroup) {
  const labels = {
    'peito': 'Peito',
    'costa': 'Costas',
    'ombro': 'Ombros',
    'bíceps': 'Bíceps',
    'tríceps': 'Tríceps',
    'antebraço': 'Antebraço',
    'core': 'Core',
    'perna_anterior': 'Quadríceps',
    'perna_posterior': 'Posterior',
    'panturrilha': 'Panturrilha',
  };
  return labels[muscleGroup] ?? muscleGroup;
}

// Estimates workout duration: time per rep (3s) + rest between sets
int estimateWorkoutDuration(List<HomeExercise> exercises) {
  if (exercises.isEmpty) return 0;
  const secsPerRep = 3;
  final total = exercises.fold<int>(
    0,
    (sum, ex) =>
        sum + (ex.series * ex.repetitions * secsPerRep) + (ex.series * ex.restSeconds),
  );
  return (total / 60).ceil().clamp(10, 120);
}

HomeMetrics computeMetrics({
  required double? weight,
  required double? height,
  required int? age,
  String? gender,
  // null = metrics endpoint not yet available
  int? weeklyWorkouts,
}) {
  if (weight == null || height == null) {
    return HomeMetrics.fallback;
  }
  if (weight <= 0 || height <= 0) {
    return HomeMetrics.fallback;
  }

  final heightM = height / 100;
  final rawImc = weight / (heightM * heightM);

  final String imcLabel;
  if (rawImc < 18.5) {
    imcLabel = 'Abaixo do peso';
  } else if (rawImc < 25) {
    imcLabel = 'Normal';
  } else if (rawImc < 30) {
    imcLabel = 'Sobrepeso';
  } else if (rawImc < 35) {
    imcLabel = 'Obeso';
  } else {
    imcLabel = 'Obeso severo';
  }

  // Harris-Benedict equation; falls back to 0 if age is absent
  final int tmb;
  if (age != null && age > 0) {
    if (gender == 'male') {
      tmb = (88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age))
          .toInt();
    } else {
      tmb = (447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age))
          .toInt();
    }
  } else {
    tmb = 0;
  }

  return HomeMetrics(
    imc: double.parse(rawImc.toStringAsFixed(1)),
    imcLabel: imcLabel,
    tmb: tmb,
    weeklyWorkouts: weeklyWorkouts,
  );
}

// Maximum exercises stored in HomeWorkout for the Home preview.
// Full list is always available in the dedicated Workouts screen.
const _kMaxExercisesPreview = 5;

// ─── Private response models ─────────────────────────────────────────────────

class _SheetListResponse {
  final List<_SheetListItem> data;

  _SheetListResponse({required this.data});

  factory _SheetListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_SheetListItem.fromJson)
        .toList();
    return _SheetListResponse(data: items);
  }
}

class _SheetListItem {
  final String id;

  _SheetListItem({required this.id});

  factory _SheetListItem.fromJson(Map<String, dynamic> json) =>
      _SheetListItem(id: json['id'].toString());
}

// ─── Service ─────────────────────────────────────────────────────────────────

class HomeService {
  final ApiClient _apiClient;

  HomeService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Fetches all Home data: user, goals, today's workout, and computed metrics.
  /// Goals and workout failures are non-fatal — partial data is returned.
  Future<HomeData> fetchHomeData() async {
    final user = await _fetchUser();

    final results = await Future.wait([
      _fetchActiveGoals(),
      _fetchTodayWorkout(),
    ]);

    final goals = results[0] as List<HomeGoal>;
    final todayWorkout = results[1] as HomeWorkout?;

    final metrics = computeMetrics(
      weight: user.weight,
      height: user.height,
      age: user.age,
      gender: user.gender,
      // TODO: pass real value when GET /api/v1/metrics endpoint is available
      weeklyWorkouts: null,
    );

    return HomeData(
      user: user,
      goals: goals,
      todayWorkout: todayWorkout,
      metrics: metrics,
    );
  }

  Future<HomeUserSummary> _fetchUser() {
    return _apiClient.get<HomeUserSummary>(
      '/users/me',
      fromJson: (data) =>
          HomeUserSummary.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<HomeGoal>> _fetchActiveGoals() async {
    try {
      return await _apiClient.get<List<HomeGoal>>(
        '/goals',
        queryParameters: {'status': 'active', 'limit': 2},
        fromJson: (data) {
          final List items;
          if (data is List) {
            items = data;
          } else if (data is Map && data.containsKey('data')) {
            items = data['data'] as List;
          } else {
            return <HomeGoal>[];
          }
          return items
              .whereType<Map<String, dynamic>>()
              .map(HomeGoal.fromJson)
              .toList();
        },
      );
    } catch (e) {
      debugPrint('[HomeService] Error fetching active goals: $e');
      return [];
    }
  }

  Future<HomeWorkout?> _fetchTodayWorkout() async {
    try {
      // Flutter weekday: 1=Mon … 7=Sun → convert to 0=Mon … 6=Sun
      final todayIndex = DateTime.now().weekday - 1;

      final list = await _apiClient.get<_SheetListResponse>(
        '/workout-sheets',
        queryParameters: {'day_of_week': todayIndex, 'limit': 1},
        fromJson: (data) =>
            _SheetListResponse.fromJson(data as Map<String, dynamic>),
      );

      if (list.data.isEmpty) return null;

      return await _fetchWorkoutDetail(list.data.first.id);
    } catch (e) {
      debugPrint('[HomeService] Error fetching today\'s workout: $e');
      return null;
    }
  }

  Future<HomeWorkout?> _fetchWorkoutDetail(String sheetId) async {
    try {
      return await _apiClient.get<HomeWorkout>(
        '/workout-sheets/$sheetId',
        fromJson: (data) {
          final json = data as Map<String, dynamic>;
          final exercises = (json['exercises'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(HomeExercise.fromJson)
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          final preview = exercises.take(_kMaxExercisesPreview).toList();

          return HomeWorkout(
            id: json['id'].toString(),
            name: json['name'] as String,
            description: json['description'] as String?,
            dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
            exercises: preview,
          );
        },
      );
    } catch (e) {
      debugPrint('[HomeService] Error fetching workout detail ($sheetId): $e');
      return null;
    }
  }
}
