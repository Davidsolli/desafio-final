import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import '../../../models/workout_sheet_model.dart';

import '../../../providers/workout_sheet_provider.dart';
import '../../../services/workout_sheet_service.dart';
import 'exercise_catalog_picker.dart';
import '../../../shared/utils/muscle_group_helper.dart';

/// Dialog para criar uma nova ficha de treino.
///
/// Permite ao Personal Trainer definir:
/// - Nome e descrição da ficha
/// - Dia da semana (RN-01: único por aluno)
/// - Exercícios via busca no catálogo da API ou adição manual
///
/// [targetUserId] - Se fornecido, a ficha será criada para este aluno.
///                  Se null, usa o ID do usuário logado (trainer/admin).
class CreateWorkoutSheetDialog extends StatefulWidget {
  final String? workoutProgramId;

  const CreateWorkoutSheetDialog({super.key, this.workoutProgramId});

  @override
  State<CreateWorkoutSheetDialog> createState() =>
      _CreateWorkoutSheetDialogState();
}

class _CreateWorkoutSheetDialogState extends State<CreateWorkoutSheetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _selectedDayOfWeek = 0;
  final List<_ExerciseFormEntry> _exercises = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final e in _exercises) {
      e.dispose();
    }
    super.dispose();
  }

  void _addBlankExercise() {
    setState(() {
      _exercises.add(_ExerciseFormEntry(order: _exercises.length + 1));
    });
  }

  Future<void> _addFromCatalog() async {
    final item = await showExerciseCatalogPicker(context);
    if (item != null && mounted) {
      setState(() {
        final entry = _ExerciseFormEntry(order: _exercises.length + 1);
        entry.nameController.text = item.name;
        entry.imageUrl = item.imageUrl;
        entry.gifUrl = item.gifUrl;
        if (item.muscleGroupMapped != null &&
            validMuscleGroups.contains(item.muscleGroupMapped)) {
          entry.selectedMuscleGroup = item.muscleGroupMapped!;
        }
        _exercises.add(entry);
      });
    }
  }

  Future<void> _pickForExistingEntry(int index) async {
    final item = await showExerciseCatalogPicker(context);
    if (item != null && mounted) {
      setState(() {
        _exercises[index].nameController.text = item.name;
        _exercises[index].imageUrl = item.imageUrl;
        _exercises[index].gifUrl = item.gifUrl;
        if (item.muscleGroupMapped != null &&
            validMuscleGroups.contains(item.muscleGroupMapped)) {
          _exercises[index].selectedMuscleGroup = item.muscleGroupMapped!;
        }
      });
    }
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises[index].dispose();
      _exercises.removeAt(index);
      // Reordena
      for (int i = 0; i < _exercises.length; i++) {
        _exercises[i].order = i + 1;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final programId = widget.workoutProgramId;
    if (programId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: ID do programa não fornecido.'),
            backgroundColor: AppColors.accentError,
          ),
        );
      }
      return;
    }

    final exerciseDTOs = _exercises.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      return ExerciseCreateDTO(
        name: e.nameController.text.trim(),
        muscleGroup: e.selectedMuscleGroup,
        series: int.tryParse(e.seriesController.text) ?? 3,
        repetitions: int.tryParse(e.repsController.text) ?? 12,
        loadKg: double.tryParse(e.loadController.text) ?? 10.0,
        restSeconds: int.tryParse(e.restController.text) ?? 60,
        observations:
            e.obsController.text.isEmpty ? null : e.obsController.text.trim(),
        imageUrl: e.imageUrl,
        gifUrl: e.gifUrl,
        order: i + 1,
      );
    }).toList();

    final dto = CreateWorkoutSheetDTO(
      workoutProgramId: programId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text.trim(),
      dayOfWeek: _selectedDayOfWeek,
      order: 1, // Default order para novas fichas
      exercises: exerciseDTOs,
    );

    setState(() => _isSubmitting = true);
    try {
      await context.read<WorkoutSheetProvider>().createSheet(dto);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on WorkoutSheetConflictException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Erro ao criar ficha: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentError,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fitness_center,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Nova Ficha de Treino',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Conteúdo scrollável
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome
                      _buildLabel('Nome da Ficha *'),
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            _inputDecoration('Ex: Treino A — Peito + Tríceps'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Nome obrigatório'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Descrição
                      _buildLabel('Descrição (opcional)'),
                      TextFormField(
                        controller: _descriptionController,
                        decoration:
                            _inputDecoration('Observações sobre o treino...'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),

                      // Dia da semana
                      _buildLabel('Dia da Semana *'),
                      DropdownButtonFormField<int>(
                        value: _selectedDayOfWeek,
                        decoration: _inputDecoration(null),
                        dropdownColor: context.colors.surface,
                        items: List.generate(7, (i) {
                          return DropdownMenuItem(
                            value: i,
                            child: Text('${dayOfWeekEmojis[i]} ${dayOfWeekLabels[i]}',
                                style: TextStyle(
                                    color: context.colors.textPrimary)),
                          );
                        }),
                        onChanged: (v) =>
                            setState(() => _selectedDayOfWeek = v ?? 0),
                      ),
                      const SizedBox(height: 20),

                      // Exercícios — cabeçalho com dois botões
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Exercícios',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              // Botão busca no catálogo (primário)
                              ElevatedButton.icon(
                                onPressed: _addFromCatalog,
                                icon: const Icon(Icons.search,
                                    size: 14, color: Colors.white),
                                label: const Text('Do Catálogo',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Botão adicionar manualmente (secundário)
                              OutlinedButton.icon(
                                onPressed: _addBlankExercise,
                                icon: const Icon(Icons.edit_outlined,
                                    size: 14, color: AppColors.primary),
                                label: const Text('Manual',
                                    style: TextStyle(
                                        color: AppColors.primary, fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_exercises.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.colors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Center(
                            child: Text(
                              'Nenhum exercício adicionado.\nClique em "Do Catálogo" para buscar ou "Manual" para digitar.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: context.colors.textMuted),
                            ),
                          ),
                        ),

                      ..._exercises.asMap().entries.map((entry) {
                        return _buildExerciseCard(entry.key, entry.value);
                      }),
                    ],
                  ),
                ),
              ),

              // Botões de ação
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.colors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancelar',
                            style: TextStyle(color: context.colors.textMuted)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Criar Ficha',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(int index, _ExerciseFormEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceLight,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exercício ${index + 1}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  // Mini botão busca no catálogo
                  GestureDetector(
                    onTap: () => _pickForExistingEntry(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              color: AppColors.primary, size: 13),
                          const SizedBox(width: 3),
                          Text('Trocar',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                  )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.accentError, size: 18),
                    onPressed: () => _removeExercise(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Nome do exercício
          TextFormField(
            controller: entry.nameController,
            decoration: _inputDecoration('Nome do exercício'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 8),

          // Grupo muscular
          DropdownButtonFormField<String>(
            value: entry.selectedMuscleGroup,
            decoration:
                _inputDecoration(null).copyWith(labelText: 'Grupo Muscular'),
            dropdownColor: context.colors.surface,
            items: validMuscleGroups.map((g) {
              return DropdownMenuItem(
                value: g,
                child: Text(MuscleGroupHelper.getName(g),
                    style:
                        TextStyle(color: context.colors.textPrimary)),
              );
            }).toList(),
            onChanged: (v) => setState(
                () => entry.selectedMuscleGroup = v ?? validMuscleGroups.first),
          ),
          const SizedBox(height: 8),

          // Séries / Reps / Carga
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: entry.seriesController,
                  keyboardType: TextInputType.number,
                  decoration:
                      _inputDecoration(null).copyWith(labelText: 'Séries'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Req.';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: entry.repsController,
                  keyboardType: TextInputType.number,
                  decoration:
                      _inputDecoration(null).copyWith(labelText: 'Reps'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Req.';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: entry.loadController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      _inputDecoration(null).copyWith(labelText: 'Carga (kg)'),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) {
                      return '> 0';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Descanso
          TextFormField(
            controller: entry.restController,
            keyboardType: TextInputType.number,
            decoration:
                _inputDecoration(null).copyWith(labelText: 'Descanso (s)'),
          ),
          const SizedBox(height: 8),

          // Observações
          TextFormField(
            controller: entry.obsController,
            decoration: _inputDecoration('Observações (opcional)'),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.colors.textMuted, fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: context.colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.colors.border),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

// ---------------------------------------------------------------------------
// Modelo interno do formulário de criação
// ---------------------------------------------------------------------------

/// Modelo interno para cada exercício no formulário de criação.
class _ExerciseFormEntry {
  int order;
  final TextEditingController nameController;
  final TextEditingController seriesController;
  final TextEditingController repsController;
  final TextEditingController loadController;
  final TextEditingController restController;
  final TextEditingController obsController;
  String selectedMuscleGroup;
  String? imageUrl;
  String? gifUrl;

  _ExerciseFormEntry({required this.order})
      : nameController = TextEditingController(),
        seriesController = TextEditingController(text: '3'),
        repsController = TextEditingController(text: '12'),
        // Fix: valor padrão > 0 para não causar erro 422 no backend
        loadController = TextEditingController(text: '10'),
        restController = TextEditingController(text: '60'),
        obsController = TextEditingController(),
        selectedMuscleGroup = validMuscleGroups.first;

  void dispose() {
    nameController.dispose();
    seriesController.dispose();
    repsController.dispose();
    loadController.dispose();
    restController.dispose();
    obsController.dispose();
  }
}

/// Constante auxiliar de emojis por dia da semana.
const dayOfWeekEmojis = ['💪', '🔥', '⚡', '🎯', '🏋️', '🚀', '😴'];
