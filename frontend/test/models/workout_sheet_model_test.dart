import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/models/workout_sheet_model.dart';

/// Testes unitários para os modelos Dart de fichas de treino.
///
/// Valida a deserialização (fromJson) e serialização (toJson)
/// dos DTOs espelhados do backend.
void main() {
  group('ExerciseResponse', () {
    test('fromJson deve criar instância correta', () {
      final json = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'workout_sheet_id': '550e8400-e29b-41d4-a716-446655440001',
        'name': 'Supino Reto',
        'muscle_group': 'peito',
        'series': 4,
        'repetitions': 12,
        'load_kg': 60.5,
        'rest_seconds': 90,
        'observations': 'Manter cotovelos a 45°',
        'image_url': null,
        'gif_url': null,
        'order': 1,
        'created_at': '2026-05-01T10:00:00',
        'updated_at': '2026-05-01T10:00:00',
      };

      final exercise = ExerciseResponse.fromJson(json);

      expect(exercise.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(exercise.name, 'Supino Reto');
      expect(exercise.muscleGroup, 'peito');
      expect(exercise.series, 4);
      expect(exercise.repetitions, 12);
      expect(exercise.loadKg, 60.5);
      expect(exercise.restSeconds, 90);
      expect(exercise.observations, 'Manter cotovelos a 45°');
      expect(exercise.order, 1);
    });

    test('fromJson com campos opcionais nulos', () {
      final json = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'workout_sheet_id': '550e8400-e29b-41d4-a716-446655440001',
        'name': 'Crucifixo',
        'muscle_group': 'peito',
        'series': 3,
        'repetitions': 15,
        'load_kg': 16.0,
        'rest_seconds': 60,
        'observations': null,
        'image_url': null,
        'gif_url': null,
        'order': 3,
        'created_at': '2026-05-01T10:00:00',
        'updated_at': '2026-05-01T10:00:00',
      };

      final exercise = ExerciseResponse.fromJson(json);

      expect(exercise.observations, isNull);
      expect(exercise.imageUrl, isNull);
      expect(exercise.gifUrl, isNull);
    });
  });

  group('WorkoutSheetResponse', () {
    test('fromJson deve criar instância com exercícios', () {
      final json = {
        'id': '550e8400-e29b-41d4-a716-446655440010',
        'user_id': '550e8400-e29b-41d4-a716-446655440020',
        'personal_trainer_id': '550e8400-e29b-41d4-a716-446655440030',
        'name': 'Treino A - Peito + Tríceps',
        'description': 'Treino de hipertrofia',
        'day_of_week': 0,
        'is_active': true,
        'created_at': '2026-05-01T10:00:00',
        'updated_at': '2026-05-01T10:00:00',
        'exercises': [
          {
            'id': '550e8400-e29b-41d4-a716-446655440100',
            'workout_sheet_id': '550e8400-e29b-41d4-a716-446655440010',
            'name': 'Supino Reto',
            'muscle_group': 'peito',
            'series': 4,
            'repetitions': 12,
            'load_kg': 60.0,
            'rest_seconds': 90,
            'order': 1,
            'created_at': '2026-05-01T10:00:00',
            'updated_at': '2026-05-01T10:00:00',
          },
        ],
      };

      final sheet = WorkoutSheetResponse.fromJson(json);

      expect(sheet.id, '550e8400-e29b-41d4-a716-446655440010');
      expect(sheet.userId, '550e8400-e29b-41d4-a716-446655440020');
      expect(sheet.personalTrainerId, '550e8400-e29b-41d4-a716-446655440030');
      expect(sheet.name, 'Treino A - Peito + Tríceps');
      expect(sheet.description, 'Treino de hipertrofia');
      expect(sheet.dayOfWeek, 0);
      expect(sheet.isActive, true);
      expect(sheet.exercises.length, 1);
      expect(sheet.exercises[0].name, 'Supino Reto');
    });

    test('dayOfWeekLabel retorna o label correto', () {
      final json = {
        'id': 'test-id',
        'user_id': 'user-id',
        'name': 'Treino B',
        'day_of_week': 1,
        'is_active': true,
        'created_at': '2026-05-01T10:00:00',
        'updated_at': '2026-05-01T10:00:00',
        'exercises': [],
      };

      final sheet = WorkoutSheetResponse.fromJson(json);

      expect(sheet.dayOfWeekLabel, 'Terça');
    });

    test('emoji retorna emoji baseado no dia', () {
      for (int i = 0; i <= 6; i++) {
        final json = {
          'id': 'test-id-$i',
          'user_id': 'user-id',
          'name': 'Treino $i',
          'day_of_week': i,
          'is_active': true,
          'created_at': '2026-05-01T10:00:00',
          'updated_at': '2026-05-01T10:00:00',
          'exercises': [],
        };
        final sheet = WorkoutSheetResponse.fromJson(json);
        expect(sheet.emoji, isNotEmpty);
      }
    });

    test('fromJson sem exercícios retorna lista vazia', () {
      final json = {
        'id': 'test-id',
        'user_id': 'user-id',
        'name': 'Treino Vazio',
        'day_of_week': 4,
        'is_active': true,
        'created_at': '2026-05-01T10:00:00',
        'updated_at': '2026-05-01T10:00:00',
      };

      final sheet = WorkoutSheetResponse.fromJson(json);
      expect(sheet.exercises, isEmpty);
    });
  });

  group('WorkoutSheetListItem', () {
    test('fromJson deve criar instância correta', () {
      final json = {
        'id': 'list-item-id',
        'user_id': 'user-id',
        'personal_trainer_id': null,
        'name': 'Treino C',
        'day_of_week': 2,
        'is_active': true,
        'exercise_count': 5,
        'created_at': '2026-05-01T10:00:00',
      };

      final item = WorkoutSheetListItem.fromJson(json);

      expect(item.id, 'list-item-id');
      expect(item.name, 'Treino C');
      expect(item.dayOfWeek, 2);
      expect(item.exerciseCount, 5);
      expect(item.dayOfWeekLabel, 'Quarta');
    });

    test('exerciseCount default é 0', () {
      final json = {
        'id': 'item-id',
        'user_id': 'user-id',
        'name': 'Treino D',
        'day_of_week': 3,
        'is_active': true,
        'created_at': '2026-05-01T10:00:00',
      };

      final item = WorkoutSheetListItem.fromJson(json);
      expect(item.exerciseCount, 0);
    });
  });

  group('PaginatedWorkoutSheets', () {
    test('fromJson deve parsear corretamente', () {
      final json = {
        'total': 3,
        'page': 1,
        'limit': 10,
        'data': [
          {
            'id': 'sheet-1',
            'user_id': 'user-1',
            'name': 'Treino A',
            'day_of_week': 0,
            'is_active': true,
            'exercise_count': 5,
            'created_at': '2026-05-01T10:00:00',
          },
          {
            'id': 'sheet-2',
            'user_id': 'user-1',
            'name': 'Treino B',
            'day_of_week': 1,
            'is_active': true,
            'exercise_count': 4,
            'created_at': '2026-05-01T10:00:00',
          },
        ],
      };

      final paginated = PaginatedWorkoutSheets.fromJson(json);

      expect(paginated.total, 3);
      expect(paginated.page, 1);
      expect(paginated.limit, 10);
      expect(paginated.data.length, 2);
      expect(paginated.data[0].name, 'Treino A');
      expect(paginated.data[1].name, 'Treino B');
    });
  });

  group('ExerciseCatalogItem', () {
    test('fromJson deve parsear corretamente', () {
      final json = {
        'id': 'cat-1',
        'name': 'Supino Reto com Barra',
        'category': 'Força',
        'level': 'Intermediário',
        'equipment': 'Barra',
        'primary_muscles': ['Peitoral Maior'],
        'secondary_muscles': ['Tríceps', 'Deltóide Anterior'],
        'instructions': ['Deite no banco', 'Desça a barra'],
        'image_url': 'https://example.com/supino.jpg',
        'gif_url': null,
        'muscle_group_mapped': 'peito',
      };

      final item = ExerciseCatalogItem.fromJson(json);

      expect(item.id, 'cat-1');
      expect(item.name, 'Supino Reto com Barra');
      expect(item.category, 'Força');
      expect(item.primaryMuscles, ['Peitoral Maior']);
      expect(item.secondaryMuscles, contains('Tríceps'));
      expect(item.instructions?.length, 2);
      expect(item.muscleGroupMapped, 'peito');
    });
  });

  group('PaginatedCatalog', () {
    test('fromJson deve parsear corretamente', () {
      final json = {
        'total': 800,
        'page': 1,
        'limit': 20,
        'data': [
          {
            'id': 'ex-1',
            'name': 'Supino Reto',
            'muscle_group_mapped': 'peito',
          },
        ],
      };

      final catalog = PaginatedCatalog.fromJson(json);

      expect(catalog.total, 800);
      expect(catalog.data.length, 1);
      expect(catalog.data[0].name, 'Supino Reto');
    });
  });

  group('CreateWorkoutSheetDTO', () {
    test('toJson deve serializar corretamente', () {
      final dto = CreateWorkoutSheetDTO(
        userId: 'user-123',
        name: 'Treino A',
        description: 'Peito + Tríceps',
        dayOfWeek: 0,
        exercises: [
          ExerciseCreateDTO(
            name: 'Supino Reto',
            muscleGroup: 'peito',
            series: 4,
            repetitions: 12,
            loadKg: 60.0,
            restSeconds: 90,
            order: 1,
          ),
        ],
      );

      final json = dto.toJson();

      expect(json['user_id'], 'user-123');
      expect(json['name'], 'Treino A');
      expect(json['description'], 'Peito + Tríceps');
      expect(json['day_of_week'], 0);
      expect(json['exercises'], isA<List>());
      expect((json['exercises'] as List).length, 1);
    });

    test('toJson sem exercícios', () {
      final dto = CreateWorkoutSheetDTO(
        userId: 'user-123',
        name: 'Treino Vazio',
        dayOfWeek: 4,
      );

      final json = dto.toJson();

      expect(json['exercises'], isEmpty);
      expect(json.containsKey('description'), false);
    });
  });

  group('UpdateWorkoutSheetDTO', () {
    test('toJson deve incluir apenas campos preenchidos', () {
      final dto = UpdateWorkoutSheetDTO(
        name: 'Treino A v2',
        dayOfWeek: 2,
      );

      final json = dto.toJson();

      expect(json['name'], 'Treino A v2');
      expect(json['day_of_week'], 2);
      expect(json.containsKey('description'), false);
      expect(json.containsKey('exercises'), false);
    });
  });

  group('DuplicateWorkoutSheetDTO', () {
    test('toJson completo', () {
      final dto = DuplicateWorkoutSheetDTO(
        name: 'Treino A (Cópia)',
        userId: 'another-user',
      );

      final json = dto.toJson();

      expect(json['name'], 'Treino A (Cópia)');
      expect(json['user_id'], 'another-user');
    });

    test('toJson vazio', () {
      final dto = DuplicateWorkoutSheetDTO();

      final json = dto.toJson();

      expect(json, isEmpty);
    });
  });

  group('Constantes', () {
    test('validMuscleGroups deve conter 10 grupos', () {
      expect(validMuscleGroups.length, 10);
      expect(validMuscleGroups, contains('peito'));
      expect(validMuscleGroups, contains('costa'));
      expect(validMuscleGroups, contains('panturrilha'));
    });

    test('dayOfWeekLabels deve ter 7 dias', () {
      expect(dayOfWeekLabels.length, 7);
      expect(dayOfWeekLabels[0], 'Segunda');
      expect(dayOfWeekLabels[6], 'Domingo');
    });
  });
}
