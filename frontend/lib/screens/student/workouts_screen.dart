import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:async';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../models/mock_data.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  String? _selectedWorkoutId;
  Set<String> _completedExercises = {};
  int? _restTimerSeconds;
  Timer? _restTimer;
  int _selectedNavIndex = 1;

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

  @override
  Widget build(BuildContext context) {
    final selectedWorkout = workouts.firstWhere(
      (w) => w.id == _selectedWorkoutId,
      orElse: () => workouts[0],
    );

    if (_selectedWorkoutId != null) {
      return _buildWorkoutDetail(selectedWorkout);
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
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  final workout = workouts[index];
                  return FadeInUp(
                    delay: Duration(milliseconds: index * 100),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedWorkoutId = workout.id),
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
                                child: Text(workout.emoji, style: const TextStyle(fontSize: 24)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(workout.name,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                                  Text(workout.label,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text('${workout.dayOfWeek} • ${workout.exercises.length} exercícios • ${workout.duration} min',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildWorkoutDetail(Workout workout) {
    final progress = (_completedExercises.length / workout.exercises.length) * 100;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => setState(() {
            _selectedWorkoutId = null;
            _completedExercises.clear();
          }),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(workout.label,
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
                  Text('${_completedExercises.length}/${workout.exercises.length}',
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
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
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
                            onPressed: _restTimer?.isActive ?? false ? _pauseRestTimer : () => _startRestTimer(_restTimerSeconds!),
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
                itemCount: workout.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = workout.exercises[index];
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
                                      Text(exercise.muscle,
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _startRestTimer(exercise.rest),
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
                                        Text('${exercise.rest}s',
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
                                _buildExerciseChip('${exercise.sets} séries'),
                                _buildExerciseChip('${exercise.reps} reps'),
                                _buildExerciseChip('${exercise.load}kg'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_completedExercises.length == workout.exercises.length)
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
                      setState(() => _selectedWorkoutId = null);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Treino ${workout.name} finalizado!')),
                      );
                    },
                    child: Text('✅ Finalizar Treino',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
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
              color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) {
          setState(() => _selectedNavIndex = index);
          final routes = [
            AppRoutes.home,
            AppRoutes.workouts,
            AppRoutes.nutrition,
            AppRoutes.chat,
            AppRoutes.profile,
          ];
          context.go(routes[index]);
        },
        backgroundColor: AppColors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center_outlined), label: 'Treinos'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), label: 'Nutrição'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
