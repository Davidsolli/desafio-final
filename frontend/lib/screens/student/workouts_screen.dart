import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../models/workout_sheet_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_sheet_provider.dart';
import '../../shared/widgets/index.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserSheets();
    });
  }

  Future<void> _loadUserSheets() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: Usuário não autenticado'),
            backgroundColor: AppColors.accentError,
          ),
        );
      }
      return;
    }

    try {
      await context.read<WorkoutSheetProvider>().loadSheets(userId: userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar fichas: $e'),
            backgroundColor: AppColors.accentError,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _restTimer = null;
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
      backgroundColor: context.colors.background,
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
                    return const OmniLoader();
                  }

                  if (provider.error != null) {
                    return OmniErrorState(
                      message: 'Erro: ${provider.error}',
                      onRetry: _loadUserSheets,
                    );
                  }

                  if (provider.sheets.isEmpty) {
                    return OmniEmptyState(
                      icon: Icons.fitness_center_outlined,
                      title: 'Nenhuma ficha atribuída',
                      subtitle: 'Seu personal trainer ainda não atribuiu fichas de treino.',
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
                                color: context.colors.surface,
                                border: Border.all(color: context.colors.border, width: 1),
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
                                                ?.copyWith(color: context.colors.textSecondary)),
                                        const SizedBox(height: 4),
                                        Text('${sheet.exerciseCount} exercícios',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(color: context.colors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: context.colors.textMuted),
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

    final exercisesCount = _selectedSheet?.exercises.length ?? 0;
    final progress = exercisesCount > 0 ? (_completedExercises.length / exercisesCount) * 100 : 0;

    return Scaffold(
      backgroundColor: context.colors.background,
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textSecondary)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: OmniProgressBar(
                value: progress / 100,
                trailingLabel: '${_completedExercises.length}/$exercisesCount',
              ),
            ),
            if (_restTimerSeconds != null && _restTimerSeconds! > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
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
                                      ?.copyWith(color: context.colors.textMuted)),
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
                            icon: Icon(Icons.close, color: context.colors.textMuted, size: 20),
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
                itemCount: _selectedSheet?.exercises.length ?? 0,
                itemBuilder: (context, index) {
                  final exercise = _selectedSheet?.exercises[index];
                  if (exercise == null) return const SizedBox.shrink();
                  final isCompleted = _completedExercises.contains(exercise.id);

                  return FadeInUp(
                    delay: Duration(milliseconds: index * 50),
                    child: GestureDetector(
                      onTap: () => _toggleExercise(exercise.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          border: Border.all(
                            color: isCompleted ? AppColors.primary : context.colors.border,
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
                                  color: isCompleted ? AppColors.primary : context.colors.textMuted,
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
                                              color: isCompleted ? context.colors.textMuted : context.colors.textPrimary)),
                                      Text(exercise.muscleGroup,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: context.colors.textMuted)),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _startRestTimer(exercise.restSeconds),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: context.colors.surface,
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
                                      color: context.colors.surfaceLight,
                                      child: Center(
                                        child: Icon(Icons.image_not_supported, color: context.colors.textMuted),
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
            if (_selectedSheet != null && _completedExercises.length == _selectedSheet!.exercises.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OmniButton(
                    text: '✅ Finalizar Treino',
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
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseChip(String text) {
    return OmniInfoChip(label: text);
  }
}
