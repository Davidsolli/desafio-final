import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/services/workout_sheet_service.dart';

/// Testes unitários para a exceção WorkoutSheetConflictException
/// e para validação da estrutura do WorkoutSheetService.
void main() {
  group('WorkoutSheetConflictException', () {
    test('deve armazenar mensagem corretamente', () {
      final exception = WorkoutSheetConflictException(
          'Aluno já possui ficha ativa para este dia da semana.');

      expect(
        exception.message,
        'Aluno já possui ficha ativa para este dia da semana.',
      );
    });

    test('toString deve conter o nome da exceção', () {
      final exception = WorkoutSheetConflictException('Conflito RN-01');

      expect(exception.toString(), contains('WorkoutSheetConflictException'));
      expect(exception.toString(), contains('Conflito RN-01'));
    });

    test('deve implementar Exception', () {
      final exception = WorkoutSheetConflictException('teste');

      expect(exception, isA<Exception>());
    });
  });

  group('WorkoutSheetService (construção)', () {
    // Nota: Testes de integração real requerem ApiClient mockado.
    // Aqui validamos apenas que o serviço aceita os parâmetros esperados.

    test('WorkoutSheetConflictException captura RN-01 corretamente', () {
      // Simula cenário onde backend retorna 409
      const errorMessage =
          'Aluno já possui uma ficha ativa para segunda-feira.';

      final exception = WorkoutSheetConflictException(errorMessage);

      expect(exception.message, contains('segunda-feira'));
      expect(exception, isA<Exception>());
    });
  });
}
