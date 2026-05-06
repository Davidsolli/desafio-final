import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../theme/app_colors.dart';
import '../../models/workout_sheet_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_sheet_provider.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  String? _selectedSheetId;
  WorkoutSheetResponse? _selectedSheet;
  Set<String> _completedExercises = {};
  int? _restTimerSeconds;
  Timer? _restTimer;

  @override
  void initState() {
    super.initState();
    _loadUserSheets();
  }

  Future<void> _loadUserSheets() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;
    if (userId != null) {
      await context.read<WorkoutSheetProvider>().loadSheets(userId: userId);
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() => _restTimerSeconds = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_restTimerSeconds! > 0) {
            _restTimerSeconds = _restTimerSeconds! - 1;
          } else {
            _restTimer?.cancel();
            _restTimerSeconds = null;
          }
        });
      }
    });
  }

  void _pauseRestTimer() {
    _restTimer?.cancel();
  }

  void _toggleExercise(String exerciseId) {
    setState(() {
      if (_completedExercises.contains(exerciseId)) {
        _completedExercises.remove(exerciseId);
      } else {
        _completedExercises.add(exerciseId);
      }
    });
  }

  Future<void> _loadSheetDetail(String sheetId) async {
    try {
      await context.read<WorkoutSheetProvider>().loadSheetDetail(sheetId);
      if (mounted) {
        final provider = context.read<WorkoutSheetProvider>();
        setState(() {
          _selectedSheetId = sheetId;
          _selectedSheet = provider.selectedSheet;
          _completedExercises.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar ficha: $e'),
            backgroundColor: AppColors.accentError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSheetId != null && _selectedSheet != null) {
      return _buildWorkoutDetail();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Fichas de Treino',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Consumer<WorkoutSheetProvider>(
                builder: (ctx, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (provider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.accentError, size: 48),
                          const SizedBox(height: 16),
                          Text('Erro: ${provider.error}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textMuted)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadUserSheets,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar Novamente'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.sheets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fitness_center_outlined, color: AppColors.textMuted, size: 48),
                          const SizedBox(height: 16),
                          Text('Nenhuma ficha atribuída',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          Text('Seu personal trainer ainda não atribuiu fichas de treino.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadUserSheets,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.sheets.length,
                      itemBuilder: (context, index) {
                        final sheet = provider.sheets[index];
                        return FadeInUp(
                          delay: Duration(milliseconds: index * 100),
                          child: GestureDetector(
                            onTap: () => _loadSheetDetail(sheet.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.border, width: 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(sheet.emoji, style: const TextStyle(fontSize: 24)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(sheet.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(fontWeight: FontWeight.bold)),
                                        Text(sheet.dayOfWeekLabel,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: AppColors.textSecondary)),
                                        const SizedBox(height: 4),
                                        Text('${sheet.exerciseCount} exercícios',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutDetail() {
    if (_selectedSheet == null) return const SizedBox.shrink();

    final exercisesCount = _selectedSheet!.exercises.length;
    final progress = exercisesCount > 0 ? (_completedExercises.length / exercisesCount) * 100 : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => setState(() {
            _selectedSheetId = null;
            _selectedSheet = null;
            _completedExercises.clear();
          }),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedSheet!.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(_selectedSheet!.dayOfWeekLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_completedExercises.length}/$exercisesCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            if (_restTimerSeconds != null && _restTimerSeconds! > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Descanso',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.textMuted)),
                              Text('${_restTimerSeconds! ~/ 60}:${(_restTimerSeconds! % 60).toString().padLeft(2, '0')}',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(_restTimer?.isActive ?? false ? Icons.pause : Icons.play_arrow,
                                color: AppColors.primary, size: 20),
                            onPressed:
                                _restTimer?.isActive ?? false ? _pauseRestTimer : () => _startRestTimer(_restTimerSeconds!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                            onPressed: () {
                              _restTimer?.cancel();
                              setState(() => _restTimerSeconds = null);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedSheet!.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = _selectedSheet!.exercises[index];
                  final isCompleted = _completedExercises.contains(exercise.id);

                  return FadeInUp(
                    delay: Duration(milliseconds: index * 50),
                    child: GestureDetector(
                      onTap: () => _toggleExercise(exercise.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(
                            color: isCompleted ? AppColors.primary : AppColors.border,
                            width: isCompleted ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isCompleted ? AppColors.primary : AppColors.textMuted,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(exercise.name,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                                              color: isCompleted ? AppColors.textMuted : AppColors.textPrimary)),
                                      Text(exercise.muscleGroup,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _startRestTimer(exercise.restSeconds),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.schedule, color: AppColors.primary, size: 14),
                                        const SizedBox(width: 4),
                                        Text('${exercise.restSeconds}s',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: AppColors.primary, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildExerciseChip('${exercise.series}x${exercise.repetitions}'),
                                _buildExerciseChip('${exercise.loadKg.toStringAsFixed(1)}kg'),
                                if (exercise.observations != null)
                                  _buildExerciseChip(exercise.observations!),
                              ],
                            ),
                            if (exercise.gifUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    exercise.gifUrl!,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 120,
                                      color: AppColors.surfaceLight,
                                      child: const Center(
                                        child: Icon(Icons.image_not_supported, color: AppColors.textMuted),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_completedExercises.length == _selectedSheet!.exercises.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedSheetId = null;
                        _selectedSheet = null;
                        _completedExercises.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Treino ${_selectedSheet?.name} finalizado!'),
                          backgroundColor: AppColors.accentSuccess,
                        ),
                      );
                    },
                    child: Text('✅ Finalizar Treino',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500));
    );
  }
}
