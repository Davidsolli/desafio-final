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
import '../../shared/widgets/index.dart';

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

class _HomeBody extends StatelessWidget {
  const _HomeBody();

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
        if (data == null) return const SizedBox.shrink();

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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildTodayWorkout(context, data),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildGoalsSection(context, data),
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
                const Text('👋', style: TextStyle(fontSize: 20)),
              ],
            ),
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
              const Text('😴', style: TextStyle(fontSize: 32)),
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

  Widget _buildChip(BuildContext context, String text) {
    return OmniInfoChip(label: text);
  }

  // ---------------------------------------------------------------------------
  // Goals section
  // ---------------------------------------------------------------------------

  Widget _buildGoalsSection(BuildContext context, HomeData data) {
    final activeGoals = data.goals.where((g) => !g.completed).take(2).toList();

    return Column(
      children: [
        OmniSectionHeader(
          title: 'Metas',
          action: GestureDetector(
            onTap: () => context.go(AppRoutes.goals),
            child: Text(
              'Ver todas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (activeGoals.isEmpty)
          OmniEmptyState(
            icon: Icons.adjust,
            title: 'Nenhuma meta ativa',
          )
        else
          ...activeGoals.map(
            (goal) => FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
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
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OmniProgressBar(value: goal.progress),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
