/// Modelos Dart para o módulo de Fichas de Treino.
///
/// Espelham os DTOs Pydantic do backend (workout_sheet_dto.py),
/// garantindo compatibilidade total com a API.

// ---------------------------------------------------------------------------
// Constantes
// ---------------------------------------------------------------------------

/// Grupos musculares válidos (sincronizado com VALID_MUSCLE_GROUPS do backend)
const validMuscleGroups = {
  'peito',
  'costa',
  'ombro',
  'bíceps',
  'tríceps',
  'antebraço',
  'core',
  'perna_anterior',
  'perna_posterior',
  'panturrilha',
};

/// Mapeamento de dia da semana (int → String)
const dayOfWeekLabels = {
  0: 'Segunda',
  1: 'Terça',
  2: 'Quarta',
  3: 'Quinta',
  4: 'Sexta',
  5: 'Sábado',
  6: 'Domingo',
};

// ---------------------------------------------------------------------------
// DTOs de Exercício (dentro da ficha)
// ---------------------------------------------------------------------------

/// DTO para criar um exercício dentro de uma ficha.
class ExerciseCreateDTO {
  final String name;
  final String muscleGroup;
  final int series;
  final int repetitions;
  final double loadKg;
  final int restSeconds;
  final String? observations;
  final String? imageUrl;
  final String? gifUrl;
  final int order;

  ExerciseCreateDTO({
    required this.name,
    required this.muscleGroup,
    required this.series,
    required this.repetitions,
    required this.loadKg,
    this.restSeconds = 60,
    this.observations,
    this.imageUrl,
    this.gifUrl,
    this.order = 1,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'muscle_group': muscleGroup,
        'series': series,
        'repetitions': repetitions,
        'load_kg': loadKg,
        'rest_seconds': restSeconds,
        if (observations != null) 'observations': observations,
        if (imageUrl != null) 'image_url': imageUrl,
        if (gifUrl != null) 'gif_url': gifUrl,
        'order': order,
      };
}

/// DTO de resposta de um exercício dentro de uma ficha.
class ExerciseResponse {
  final String id;
  final String workoutSheetId;
  final String name;
  final String muscleGroup;
  final int series;
  final int repetitions;
  final double loadKg;
  final int restSeconds;
  final String? observations;
  final String? imageUrl;
  final String? gifUrl;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExerciseResponse({
    required this.id,
    required this.workoutSheetId,
    required this.name,
    required this.muscleGroup,
    required this.series,
    required this.repetitions,
    required this.loadKg,
    required this.restSeconds,
    this.observations,
    this.imageUrl,
    this.gifUrl,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExerciseResponse.fromJson(Map<String, dynamic> json) {
    return ExerciseResponse(
      id: json['id'] as String,
      workoutSheetId: json['workout_sheet_id'] as String,
      name: json['name'] as String,
      muscleGroup: json['muscle_group'] as String,
      series: json['series'] as int,
      repetitions: json['repetitions'] as int,
      loadKg: (json['load_kg'] as num).toDouble(),
      restSeconds: json['rest_seconds'] as int,
      observations: json['observations'] as String?,
      imageUrl: json['image_url'] as String?,
      gifUrl: json['gif_url'] as String?,
      order: json['order'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// DTOs de Ficha de Treino
// ---------------------------------------------------------------------------

/// DTO para criar uma nova ficha de treino.
class CreateWorkoutSheetDTO {
  final String workoutProgramId;
  final String name;
  final String? description;
  final int? dayOfWeek;
  final int order;
  final List<ExerciseCreateDTO> exercises;

  CreateWorkoutSheetDTO({
    required this.workoutProgramId,
    required this.name,
    this.description,
    this.dayOfWeek,
    this.order = 1,
    this.exercises = const [],
  });

  Map<String, dynamic> toJson() => {
        'workout_program_id': workoutProgramId,
        'name': name,
        if (description != null) 'description': description,
        if (dayOfWeek != null) 'day_of_week': dayOfWeek,
        'order': order,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}

/// DTO para atualizar uma ficha de treino (todos os campos opcionais).
class UpdateWorkoutSheetDTO {
  final String? name;
  final String? description;
  final int? dayOfWeek;
  final int? order;
  final List<ExerciseCreateDTO>? exercises;

  UpdateWorkoutSheetDTO({
    this.name,
    this.description,
    this.dayOfWeek,
    this.order,
    this.exercises,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (description != null) map['description'] = description;
    if (dayOfWeek != null) map['day_of_week'] = dayOfWeek;
    if (order != null) map['order'] = order;
    if (exercises != null) {
      map['exercises'] = exercises!.map((e) => e.toJson()).toList();
    }
    return map;
  }
}

/// DTO para duplicar uma ficha de treino.
class DuplicateWorkoutSheetDTO {
  final String? name;
  final String? workoutProgramId;

  DuplicateWorkoutSheetDTO({
    this.name,
    this.workoutProgramId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (workoutProgramId != null) map['workout_program_id'] = workoutProgramId;
    return map;
  }
}

/// Resposta completa de uma ficha de treino (com exercícios).
class WorkoutSheetResponse {
  final String id;
  final String workoutProgramId;
  final String name;
  final String? description;
  final int? dayOfWeek;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ExerciseResponse> exercises;

  WorkoutSheetResponse({
    required this.id,
    required this.workoutProgramId,
    required this.name,
    this.description,
    this.dayOfWeek,
    required this.order,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.exercises = const [],
  });

  factory WorkoutSheetResponse.fromJson(Map<String, dynamic> json) {
    return WorkoutSheetResponse(
      id: json['id'] as String,
      workoutProgramId: json['workout_program_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      dayOfWeek: json['day_of_week'] as int?,
      order: json['order'] as int? ?? 1,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => ExerciseResponse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Retorna o label do dia da semana
  String get dayOfWeekLabel => dayOfWeek != null ? (dayOfWeekLabels[dayOfWeek!] ?? 'Desconhecido') : 'Geral';

  /// Retorna emoji baseado no dia da semana
  String get emoji {
    if (dayOfWeek == null) return '💪';
    switch (dayOfWeek) {
      case 0:
        return '💪';
      case 1:
        return '🔙';
      case 2:
        return '🦵';
      case 3:
        return '🏋️';
      case 4:
        return '🔥';
      case 5:
        return '⚡';
      case 6:
        return '🧘';
      default:
        return '💪';
    }
  }
}

/// Item de ficha na listagem (sem exercícios completos, com contagem).
class WorkoutSheetListItem {
  final String id;
  final String workoutProgramId;
  final String name;
  final int? dayOfWeek;
  final int order;
  final bool isActive;
  final int exerciseCount;
  final DateTime createdAt;

  WorkoutSheetListItem({
    required this.id,
    required this.workoutProgramId,
    required this.name,
    this.dayOfWeek,
    required this.order,
    required this.isActive,
    this.exerciseCount = 0,
    required this.createdAt,
  });

  factory WorkoutSheetListItem.fromJson(Map<String, dynamic> json) {
    return WorkoutSheetListItem(
      id: json['id'] as String,
      workoutProgramId: json['workout_program_id'] as String,
      name: json['name'] as String,
      dayOfWeek: json['day_of_week'] as int?,
      order: json['order'] as int? ?? 1,
      isActive: json['is_active'] as bool,
      exerciseCount: json['exercise_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Retorna o label do dia da semana
  String get dayOfWeekLabel => dayOfWeek != null ? (dayOfWeekLabels[dayOfWeek!] ?? 'Desconhecido') : 'Geral';

  /// Retorna emoji baseado no dia da semana
  String get emoji {
    if (dayOfWeek == null) return '💪';
    switch (dayOfWeek) {
      case 0:
        return '💪';
      case 1:
        return '🔙';
      case 2:
        return '🦵';
      case 3:
        return '🏋️';
      case 4:
        return '🔥';
      case 5:
        return '⚡';
      case 6:
        return '🧘';
      default:
        return '💪';
    }
  }
}

/// Resposta paginada de fichas de treino.
class PaginatedWorkoutSheets {
  final int total;
  final int page;
  final int limit;
  final List<WorkoutSheetListItem> data;

  PaginatedWorkoutSheets({
    required this.total,
    required this.page,
    required this.limit,
    required this.data,
  });

  factory PaginatedWorkoutSheets.fromJson(Map<String, dynamic> json) {
    return PaginatedWorkoutSheets(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      data: (json['data'] as List<dynamic>)
          .map((e) => WorkoutSheetListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// DTOs de Programas de Treino
// ---------------------------------------------------------------------------

class CreateWorkoutProgramDTO {
  final String userId;
  final String name;
  final String? description;
  final String? goal;
  final List<CreateWorkoutSheetDTO> workoutSheets;

  CreateWorkoutProgramDTO({
    required this.userId,
    required this.name,
    this.description,
    this.goal,
    this.workoutSheets = const [],
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        if (description != null) 'description': description,
        if (goal != null) 'goal': goal,
        'workout_sheets': workoutSheets.map((e) => e.toJson()).toList(),
      };
}

class UpdateWorkoutProgramDTO {
  final String? name;
  final String? description;
  final String? goal;
  final bool? isActive;

  UpdateWorkoutProgramDTO({
    this.name,
    this.description,
    this.goal,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (description != null) map['description'] = description;
    if (goal != null) map['goal'] = goal;
    if (isActive != null) map['is_active'] = isActive;
    return map;
  }
}

class WorkoutProgramResponse {
  final String id;
  final String userId;
  final String? personalTrainerId;
  final String name;
  final String? description;
  final String? goal;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WorkoutSheetResponse> workoutSheets;

  WorkoutProgramResponse({
    required this.id,
    required this.userId,
    this.personalTrainerId,
    required this.name,
    this.description,
    this.goal,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.workoutSheets = const [],
  });

  factory WorkoutProgramResponse.fromJson(Map<String, dynamic> json) {
    return WorkoutProgramResponse(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      personalTrainerId: json['personal_trainer_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      goal: json['goal'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      workoutSheets: (json['workout_sheets'] as List<dynamic>?)
              ?.map((e) => WorkoutSheetResponse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PaginatedWorkoutPrograms {
  final int total;
  final int page;
  final int limit;
  final List<WorkoutProgramResponse> data;

  PaginatedWorkoutPrograms({
    required this.total,
    required this.page,
    required this.limit,
    required this.data,
  });

  factory PaginatedWorkoutPrograms.fromJson(Map<String, dynamic> json) {
    return PaginatedWorkoutPrograms(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      data: (json['data'] as List<dynamic>)
          .map((e) => WorkoutProgramResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// DTOs do Catálogo de Exercícios
// ---------------------------------------------------------------------------

/// Item do catálogo de exercícios (para busca/autocompletar).
class ExerciseCatalogItem {
  final String id;
  final String name;
  final String? category;
  final String? level;
  final String? equipment;
  final List<String>? primaryMuscles;
  final List<String>? secondaryMuscles;
  final List<String>? instructions;
  final String? imageUrl;
  final String? gifUrl;
  final String? muscleGroupMapped;

  ExerciseCatalogItem({
    required this.id,
    required this.name,
    this.category,
    this.level,
    this.equipment,
    this.primaryMuscles,
    this.secondaryMuscles,
    this.instructions,
    this.imageUrl,
    this.gifUrl,
    this.muscleGroupMapped,
  });

  factory ExerciseCatalogItem.fromJson(Map<String, dynamic> json) {
    return ExerciseCatalogItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      level: json['level'] as String?,
      equipment: json['equipment'] as String?,
      primaryMuscles: (json['primary_muscles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      secondaryMuscles: (json['secondary_muscles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      instructions: (json['instructions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      imageUrl: json['image_url'] as String?,
      gifUrl: json['gif_url'] as String?,
      muscleGroupMapped: json['muscle_group_mapped'] as String?,
    );
  }
}

/// Resposta paginada do catálogo de exercícios.
class PaginatedCatalog {
  final int total;
  final int page;
  final int limit;
  final List<ExerciseCatalogItem> data;

  PaginatedCatalog({
    required this.total,
    required this.page,
    required this.limit,
    required this.data,
  });

  factory PaginatedCatalog.fromJson(Map<String, dynamic> json) {
    return PaginatedCatalog(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      data: (json['data'] as List<dynamic>)
          .map((e) => ExerciseCatalogItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
