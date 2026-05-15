import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import '../../../models/workout_sheet_model.dart';
import '../../../providers/workout_sheet_provider.dart';
import '../../../services/workout_sheet_service.dart';
import 'exercise_catalog_picker.dart';
import '../../../shared/utils/muscle_group_helper.dart';

/// Dialog para editar uma ficha de treino existente.
///
/// Recebe o [sheetId] e carrega os detalhes completos (com exercícios)
/// antes de exibir o formulário pré-preenchido.
class EditWorkoutSheetDialog extends StatefulWidget {
  final String sheetId;

  const EditWorkoutSheetDialog({super.key, required this.sheetId});

  @override
  State<EditWorkoutSheetDialog> createState() => _EditWorkoutSheetDialogState();
}

class _EditWorkoutSheetDialogState extends State<EditWorkoutSheetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _selectedDayOfWeek;
  final List<_ExerciseEditEntry> _exercises = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSheet());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final e in _exercises) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSheet() async {
    try {
      await context.read<WorkoutSheetProvider>().loadSheetDetail(widget.sheetId);
      final sheet = context.read<WorkoutSheetProvider>().selectedSheet;
      if (sheet != null && mounted) {
        _nameController.text = sheet.name;
        _descriptionController.text = sheet.description ?? '';
        _selectedDayOfWeek = sheet.dayOfWeek;

        // Pré-popula os exercícios ordenados
        final sorted = List<ExerciseResponse>.from(sheet.exercises)
          ..sort((a, b) => a.order.compareTo(b.order));

        for (final ex in sorted) {
          _exercises.add(_ExerciseEditEntry.fromResponse(ex));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = 'Não foi possível carregar a ficha.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addExercise() {
    setState(() {
      _exercises.add(_ExerciseEditEntry(order: _exercises.length + 1));
    });
  }

  Future<void> _pickFromCatalog(int index) async {
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
      for (int i = 0; i < _exercises.length; i++) {
        _exercises[i].order = i + 1;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final exerciseDTOs = _exercises.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final load = double.tryParse(e.loadController.text) ?? 0.0;
       return ExerciseCreateDTO(
        name: e.nameController.text.trim(),
        muscleGroup: e.selectedMuscleGroup,
        series: int.tryParse(e.seriesController.text) ?? 3,
        repetitions: int.tryParse(e.repsController.text) ?? 12,
        loadKg: load,
        restSeconds: int.tryParse(e.restController.text) ?? 60,
        observations:
            e.obsController.text.isEmpty ? null : e.obsController.text.trim(),
        imageUrl: e.imageUrl,
        gifUrl: e.gifUrl,
        order: i + 1,
      );
    }).toList();

    final dto = UpdateWorkoutSheetDTO(
      name: _nameController.text.trim(),
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text.trim(),
      dayOfWeek: _selectedDayOfWeek,
      exercises: exerciseDTOs,
    );

    setState(() => _isSubmitting = true);
    try {
      await context
          .read<WorkoutSheetProvider>()
          .updateSheet(widget.sheetId, dto);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on WorkoutSheetConflictException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Erro ao atualizar ficha: ${e.toString()}');
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Editar Ficha de Treino',
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

            // Conteúdo
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    )
                  : _loadError != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.accentError, size: 40),
                              const SizedBox(height: 12),
                              Text(_loadError!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: context.colors.textMuted)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                    _loadError = null;
                                  });
                                  _loadSheet();
                                },
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      : Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Nome da Ficha *'),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: _inputDecoration(
                                      'Ex: Treino A — Peito + Tríceps'),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Nome obrigatório'
                                          : null,
                                ),
                                const SizedBox(height: 12),

                                _buildLabel('Descrição (opcional)'),
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: _inputDecoration(
                                      'Observações sobre o treino...'),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),

                                _buildLabel('Dia da Semana (opcional)'),
                                DropdownButtonFormField<int?>(
                                  value: _selectedDayOfWeek,
                                  decoration: _inputDecoration(null),
                                  dropdownColor: context.colors.surface,
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Nenhum (Rotina Flutuante)'),
                                    ),
                                    ...List.generate(7, (i) {
                                      return DropdownMenuItem<int?>(
                                        value: i,
                                        child: Text(
                                            '${_dayEmoji(i)} ${_dayLabel(i)}',
                                            style: TextStyle(
                                                color: context.colors.textPrimary)),
                                      );
                                    })
                                  ],
                                  onChanged: (v) => setState(
                                      () => _selectedDayOfWeek = v),
                                ),
                                const SizedBox(height: 20),

                                // Cabeçalho exercícios
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Exercícios (${_exercises.length})',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600)),
                                    TextButton.icon(
                                      onPressed: _addExercise,
                                      icon: const Icon(Icons.add,
                                          size: 16,
                                          color: AppColors.primary),
                                      label: const Text('Adicionar',
                                          style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12)),
                                    ),
                                  ],
                                ),

                                if (_exercises.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: context.colors.surfaceLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border:
                                          Border.all(color: context.colors.border),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Nenhum exercício.\nClique em "Adicionar" para incluir.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                                color: context.colors.textMuted),
                                      ),
                                    ),
                                  ),

                                ..._exercises.asMap().entries.map((entry) =>
                                    _buildExerciseCard(
                                        entry.key, entry.value)),
                              ],
                            ),
                          ),
                        ),
            ),

            // Botões
            if (!_isLoading && _loadError == null)
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
                            : const Text('Salvar Alterações',
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
    );
  }

  Widget _buildExerciseCard(int index, _ExerciseEditEntry entry) {
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
          // Cabeçalho do card de exercício
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exercício ${index + 1}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  // Botão buscar no catálogo
                  GestureDetector(
                    onTap: () => _pickFromCatalog(index),
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
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: 4),
                          Text('Catálogo',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: AppColors.primary, fontSize: 11)),
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

          // Nome
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
            decoration: _inputDecoration(null).copyWith(labelText: 'Grupo Muscular'),
            dropdownColor: context.colors.surface,
            items: validMuscleGroups.map((g) {
              return DropdownMenuItem(
                value: g,
                child: Text(MuscleGroupHelper.getName(g),
                    style: TextStyle(color: context.colors.textPrimary)),
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
                    if (n == null || n <= 0) return '> 0';
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

  String _dayLabel(int i) {
    const labels = [
      'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'
    ];
    return labels[i];
  }

  String _dayEmoji(int i) {
    const emojis = ['💪', '🔥', '⚡', '🎯', '🏋️', '🚀', '😴'];
    return emojis[i];
  }
}

// ---------------------------------------------------------------------------
// Modelo interno do formulário de edição
// ---------------------------------------------------------------------------

class _ExerciseEditEntry {
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

  _ExerciseEditEntry({required this.order})
      : nameController = TextEditingController(),
        seriesController = TextEditingController(text: '3'),
        repsController = TextEditingController(text: '12'),
        loadController = TextEditingController(text: '10'),
        restController = TextEditingController(text: '60'),
        obsController = TextEditingController(),
        selectedMuscleGroup = validMuscleGroups.first;

  /// Constrói a partir de um exercício já existente (pré-preenche campos).
  factory _ExerciseEditEntry.fromResponse(ExerciseResponse ex) {
    final entry = _ExerciseEditEntry(order: ex.order);
    entry.nameController.text = ex.name;
    entry.seriesController.text = ex.series.toString();
    entry.repsController.text = ex.repetitions.toString();
    entry.loadController.text = ex.loadKg.toString();
    entry.restController.text = ex.restSeconds.toString();
    entry.obsController.text = ex.observations ?? '';
    entry.imageUrl = ex.imageUrl;
    entry.gifUrl = ex.gifUrl;
    if (validMuscleGroups.contains(ex.muscleGroup)) {
      entry.selectedMuscleGroup = ex.muscleGroup;
    }
    return entry;
  }

  void dispose() {
    nameController.dispose();
    seriesController.dispose();
    repsController.dispose();
    loadController.dispose();
    restController.dispose();
    obsController.dispose();
  }
}
