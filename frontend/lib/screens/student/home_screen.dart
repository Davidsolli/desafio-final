import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/home_provider.dart';
import '../../services/home_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  String _userRole = 'student';

  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.home_outlined, 'label': 'Home', 'route': AppRoutes.home},
    {'icon': Icons.fitness_center_outlined, 'label': 'Treinos', 'route': AppRoutes.workouts},
    {'icon': Icons.restaurant_outlined, 'label': 'Nutrição', 'route': AppRoutes.nutrition},
    {'icon': Icons.chat_bubble_outline, 'label': 'Chat', 'route': AppRoutes.chat},
    {'icon': Icons.person_outline, 'label': 'Perfil', 'route': AppRoutes.profile},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().fetchHomeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<HomeProvider>(
        builder: (context, homeProvider, _) {
          if (homeProvider.isLoading && !homeProvider.hasData) {
            return _buildLoadingState();
          }
          if (homeProvider.error != null && !homeProvider.hasData) {
            return _buildErrorState(homeProvider.error!, homeProvider);
          }
          final data = homeProvider.data;
          return SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: homeProvider.fetchHomeData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: _buildHeader(data?.user.name ?? ''),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildStatsRow(data?.metrics),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildTodayWorkout(data?.todayWorkout),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildGoalsSection(data?.goals ?? []),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── States ────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const SafeArea(
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildErrorState(String error, HomeProvider homeProvider) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_outlined, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              Text(
                error,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: homeProvider.fetchHomeData,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(String fullName) {
    final firstName = fullName.isNotEmpty ? fullName.split(' ').first : '';
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá,',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            Row(
              children: [
                Text(
                  firstName,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                const Text('👋', style: TextStyle(fontSize: 20)),
              ],
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: _userRole,
            onChanged: (value) => setState(() => _userRole = value ?? 'student'),
            items: [
              DropdownMenuItem(
                  value: 'student',
                  child: Text('Aluno', style: Theme.of(context).textTheme.bodySmall)),
              DropdownMenuItem(
                  value: 'trainer',
                  child: Text('Personal', style: Theme.of(context).textTheme.bodySmall)),
            ],
            underline: const SizedBox(),
            style: const TextStyle(color: AppColors.textPrimary),
            dropdownColor: AppColors.surface,
            icon: const Icon(Icons.expand_more, color: AppColors.primary, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.go(AppRoutes.notifications),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_outlined,
                    color: AppColors.textMuted, size: 20),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Stats ─────────────────────────────────────────────────────────────────

  Widget _buildStatsRow(HomeMetrics? metrics) {
    final stats = [
      {
        'icon': Icons.trending_up,
        'value': metrics?.imcDisplay ?? '—',
        'label': 'IMC — ${metrics != null && metrics.imc > 0 ? metrics.imcLabel : '—'}',
        'delay': 0,
      },
      {
        'icon': Icons.local_fire_department,
        'value': metrics?.tmbDisplay ?? '—',
        'label': 'kcal/dia',
        'delay': 100,
      },
      {
        'icon': Icons.fitness_center,
        'value': metrics?.weeklyWorkoutsDisplay ?? '—',
        'label': 'treinos',
        'delay': 200,
      },
    ];

    return Row(
      children: stats.map((s) {
        return Expanded(
          child: FadeInUp(
            delay: Duration(milliseconds: s['delay'] as int),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(s['icon'] as IconData, color: AppColors.primary, size: 18),
                  const SizedBox(height: 6),
                  Text(
                    '${s['value']}',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s['label']}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Today's Workout ───────────────────────────────────────────────────────

  Widget _buildTodayWorkout(HomeWorkout? workout) {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.workouts),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: workout != null
              ? _buildWorkoutContent(workout)
              : _buildNoWorkoutContent(),
        ),
      ),
    );
  }

  Widget _buildWorkoutContent(HomeWorkout workout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TREINO DE HOJE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.5,
                    color: AppColors.textMuted,
                  ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(workout.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  workout.estimatedDurationMinutes > 0
                      ? '${workout.label} • ${workout.estimatedDurationMinutes} min'
                      : workout.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        if (workout.exercises.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              ...workout.exercises.take(3).map((ex) => _buildChip(ex.name)),
              if (workout.exercises.length > 3)
                _buildChip('+${workout.exercises.length - 3}'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNoWorkoutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TREINO DE HOJE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.5,
                    color: AppColors.textMuted,
                  ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('😴', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dia de descanso',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Sem treino programado para hoje',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textMuted, fontSize: 11),
      ),
    );
  }

  // ─── Goals ─────────────────────────────────────────────────────────────────

  Widget _buildGoalsSection(List<HomeGoal> goals) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.adjust, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Metas',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => context.go(AppRoutes.goals),
              child: Text(
                'Ver todas',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (goals.isEmpty)
          _buildEmptyGoals()
        else
          ...goals.map((goal) {
            return FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(goal.progress * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: goal.progress,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyGoals() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, color: AppColors.textMuted, size: 24),
          const SizedBox(width: 12),
          Text(
            'Nenhuma meta ativa',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Nav ────────────────────────────────────────────────────────────

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
          context.go(_navItems[index]['route']);
        },
        backgroundColor: AppColors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        items: _navItems
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item['icon'] as IconData, size: 24),
                label: item['label'] as String,
              ),
            )
            .toList(),
      ),
    );
  }
}
