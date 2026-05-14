import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/home_service.dart';
import '../../providers/home_provider.dart';
import '../../providers/logbook_provider.dart';
import '../../shared/widgets/index.dart';
import '../../widgets/progress_widgets.dart';
import 'widgets/step_summary_card.dart';
import 'widgets/heart_rate_summary_card.dart';

// HomeScreen creates and injects HomeProvider locally so main.dart stays
// untouched. The provider is scoped to this route and disposed with it.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = context.read<ApiClient>();
    return ChangeNotifierProvider(
      create: (_) => HomeProvider(
        homeService: HomeService(apiClient: apiClient),
      )..fetchHomeData(),
      child: const _HomeBody(),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LogbookProvider>().loadSessions().catchError((e) {
        debugPrint('Erro ao carregar sessões no Home: $e');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, provider, _) {
        // ----- Loading -----
        if (provider.isLoading) {
          return Scaffold(
            backgroundColor: context.colors.background,
            body: const OmniLoader(),
          );
        }

        // ----- Error -----
        if (provider.error != null) {
          return Scaffold(
            backgroundColor: context.colors.background,
            body: OmniErrorState(
              message: provider.error!,
              icon: Icons.wifi_off_outlined,
              onRetry: provider.fetchHomeData,
            ),
          );
        }

        // ----- Success -----
        final data = provider.data;
        if (data == null) {
          return Scaffold(
            backgroundColor: context.colors.background,
            body: OmniErrorState(
              message: 'Não foi possível carregar os dados',
              onRetry: provider.fetchHomeData,
            ),
          );
        }

        return Scaffold(
          backgroundColor: context.colors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: _buildHeader(context, data),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildStatsRow(context, data),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: StepSummaryCard(),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: HeartRateSummaryCard(),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildNutritionCard(context, data),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildTodayWorkout(context, data),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: WorkoutHistorySection(),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildQuickActions(context),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, HomeData data) {
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
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            Row(
              children: [
                Text(
                  data.user.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.waving_hand_outlined, color: AppColors.accentWarning, size: 20),
              ],
            ),
            if (data.workoutStreak > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${data.workoutStreak} ${data.workoutStreak == 1 ? 'dia' : 'dias'} consecutivos',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => context.push(AppRoutes.notifications),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border.all(color: context.colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.notifications_outlined,
                    color: context.colors.textMuted, size: 20),
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

  // ---------------------------------------------------------------------------
  // Stats row (IMC, TMB)
  // ---------------------------------------------------------------------------

  Widget _buildStatsRow(BuildContext context, HomeData data) {
    final user = data.user;
    final imcValue = user.imc?.toStringAsFixed(1) ?? '—';
    final imcLabel = user.imc != null ? 'IMC — ${user.imcLabel}' : 'IMC';
    final tmbValue = user.tmb?.toString() ?? '—';

    return Row(
      children: [
        Expanded(
          child: FadeInUp(
            delay: Duration.zero,
            child: OmniStatCard(
              icon: Icons.trending_up,
              value: imcValue,
              label: imcLabel,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: OmniStatCard(
              icon: Icons.local_fire_department,
              value: tmbValue,
              label: 'kcal/dia',
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Today's workout
  // ---------------------------------------------------------------------------

  Widget _buildTodayWorkout(BuildContext context, HomeData data) {
    final workout = data.todayWorkout;

    if (workout == null) {
      return FadeInUp(
        delay: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border.all(color: context.colors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.bedtime_outlined, color: context.colors.textMuted, size: 32),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dia de descanso',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                            fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Nenhum treino programado para hoje',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final durationText = workout.duration != null
        ? '${workout.label} • ${workout.duration} min'
        : workout.label;

    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.workouts),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border.all(color: context.colors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TREINO DE HOJE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.5, color: context.colors.textMuted),
                  ),
                  Icon(Icons.chevron_right,
                      color: context.colors.textMuted, size: 20),
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
                      child: Text(
                        workout.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          durationText,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (workout.exercises.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    ...workout.exercises
                        .take(3)
                        .map((ex) => _buildChip(context, ex.name)),
                    if (workout.exercises.length > 3)
                      _buildChip(
                          context, '+${workout.exercises.length - 3}'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Nutrition today
  // ---------------------------------------------------------------------------

  Widget _buildNutritionCard(BuildContext context, HomeData data) {
    final consumed = data.todayKcal;
    final goal = data.user.tmb;
    final ratio = (goal != null && goal > 0)
        ? (consumed / goal).clamp(0.0, 1.0)
        : 0.0;
    final pct = (ratio * 100).toStringAsFixed(0);

    Color barColor = AppColors.primary;
    if (goal != null && goal > 0) {
      final r = consumed / goal;
      if (r > 1.2) {
        barColor = AppColors.accentError;
      } else if (r > 1.0) {
        barColor = AppColors.accentWarning;
      }
    }

    return FadeInUp(
      delay: const Duration(milliseconds: 250),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.nutrition),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border.all(color: context.colors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'NUTRIÇÃO HOJE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.5, color: context.colors.textMuted),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.restaurant_outlined,
                          color: AppColors.accentInfo, size: 18),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          color: context.colors.textMuted, size: 20),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Kcal row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    consumed.toString(),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      goal != null ? '/ $goal kcal (basal)' : 'kcal',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary),
                    ),
                  ),
                  const Spacer(),
                  if (goal != null)
                    Text(
                      '$pct%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: barColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                ],
              ),
              // Progress bar
              if (goal != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: context.colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Macros pills
              Row(
                children: [
                  Expanded(
                    child: _buildMacroPill(
                      context,
                      label: 'Proteína',
                      value: data.todayProtein,
                      color: AppColors.accentInfo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroPill(
                      context,
                      label: 'Carboidrato',
                      value: data.todayCarbs,
                      color: AppColors.accentWarning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroPill(
                      context,
                      label: 'Gordura',
                      value: data.todayFats,
                      color: AppColors.accentError,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroPill(
    BuildContext context, {
    required String label,
    required double value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '${value.toStringAsFixed(0)}g',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color.withOpacity(0.85),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String text) {
    return OmniInfoChip(label: text);
  }

  // ---------------------------------------------------------------------------
  // Quick actions
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        OmniSectionHeader(title: 'Ações Rápidas'),
        const SizedBox(height: 12),
        FadeInUp(
          delay: const Duration(milliseconds: 300),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  icon: Icons.fitness_center_outlined,
                  label: 'Treinar',
                  color: AppColors.primary,
                  onTap: () => context.go(AppRoutes.workouts),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  icon: Icons.restaurant_outlined,
                  label: 'Refeição',
                  color: AppColors.accentWarning,
                  onTap: () => context.go(AppRoutes.nutrition),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat IA',
                  color: AppColors.accentInfo,
                  onTap: () => context.go(AppRoutes.chat),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }


}
