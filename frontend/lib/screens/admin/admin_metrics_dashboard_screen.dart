import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_metrics_provider.dart';
import '../../providers/admin_provider.dart';
import '../../shared/widgets/omni_error_state.dart';
import '../../shared/widgets/omni_loader.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import 'widgets/student_metrics_card.dart';
import 'widgets/system_health_card.dart';
import 'widgets/trainer_metrics_card.dart';

class AdminMetricsDashboardScreen extends StatefulWidget {
  const AdminMetricsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminMetricsDashboardScreen> createState() =>
      _AdminMetricsDashboardScreenState();
}

class _AdminMetricsDashboardScreenState
    extends State<AdminMetricsDashboardScreen> {
  static const _periods = [7, 14, 30, 90];

  @override
  void initState() {
    super.initState();
    // Carrega todos os cards na primeira abertura.
    // Também garante que AdminProvider já tem a lista de trainers para o filtro.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final metricsProvider = context.read<AdminMetricsProvider>();
      final adminProvider = context.read<AdminProvider>();
      metricsProvider.loadAll();
      if (adminProvider.trainers.isEmpty) {
        adminProvider.loadTrainers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminMetricsProvider>();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(context, provider),
      body: Column(
        children: [
          _PeriodFilterBar(
            selected: provider.selectedDays,
            periods: _periods,
            onSelected: (days) => provider.changePeriod(days),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadAll(),
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Card 1 — Saúde do Sistema
                  _CardContainer(
                    isLoading: provider.loadingSystem,
                    error: provider.systemError,
                    onRetry: () => provider.loadSystem(),
                    child: provider.systemMetrics != null
                        ? SystemHealthCard(data: provider.systemMetrics!)
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Card 2 — Alunos
                  StudentMetricsCard(
                    data: provider.studentMetrics,
                    isLoading: provider.loadingStudents,
                    hasMore: provider.hasMoreStudents,
                    error: provider.studentError,
                    onRetry: () => provider.loadStudents(resetPage: true),
                    onLoadMore: () => provider.loadMoreStudents(),
                    onTrainerFilterChanged: (trainerId) =>
                        provider.changeTrainerFilter(trainerId),
                  ),
                  const SizedBox(height: 16),

                  // Card 3 — Trainers
                  TrainerMetricsCard(
                    data: provider.trainerMetrics,
                    isLoading: provider.loadingTrainers,
                    error: provider.trainerError,
                    onRetry: () => provider.loadTrainers(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, AdminMetricsProvider provider) {
    return AppBar(
      backgroundColor: context.colors.surface,
      elevation: 0,
      title: const Text('Métricas'),
      actions: [
        if (provider.isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Atualizar',
            onPressed: () => provider.loadAll(),
          ),
      ],
    );
  }

}

/// Container universal para cards que gerencia estados loading/error/empty.
class _CardContainer extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final Widget? child;

  const _CardContainer({
    required this.isLoading,
    this.error,
    this.onRetry,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && child == null) {
      return Card(
        color: context.colors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const SizedBox(
          height: 120,
          child: Center(child: OmniLoader()),
        ),
      );
    }

    if (error != null && child == null) {
      return Card(
        color: context.colors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OmniErrorState(
            message: error!,
            onRetry: onRetry,
          ),
        ),
      );
    }

    return child ?? const SizedBox.shrink();
  }
}

/// Barra de chips para seleção de período.
class _PeriodFilterBar extends StatelessWidget {
  final int selected;
  final List<int> periods;
  final ValueChanged<int> onSelected;

  const _PeriodFilterBar({
    required this.selected,
    required this.periods,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: periods.map((days) {
          final isSelected = days == selected;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onSelected(days),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : context.colors.border,
                    ),
                  ),
                  child: Text(
                    '${days}d',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isSelected
                              ? Colors.white
                              : context.colors.textMuted,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
