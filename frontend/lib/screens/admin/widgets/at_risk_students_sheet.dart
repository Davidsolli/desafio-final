import 'package:flutter/material.dart';
import '../../../models/admin_metrics_models.dart';
import '../../../shared/widgets/omni_avatar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';

class AtRiskStudentsSheet extends StatelessWidget {
  final List<StudentMetricsItemDTO> students;

  const AtRiskStudentsSheet({Key? key, required this.students}) : super(key: key);

  List<StudentMetricsItemDTO> _byRisk(String level) =>
      students.where((s) => s.riskLevel == level).toList();

  @override
  Widget build(BuildContext context) {
    final critical = _byRisk('critical');
    final high = _byRisk('high');
    final medium = _byRisk('medium');

    final tabs = <_RiskTab>[
      _RiskTab(
        label: '🔴 Crítico',
        count: critical.length,
        color: AppColors.accentError,
        students: critical,
      ),
      _RiskTab(
        label: '🟠 Alto',
        count: high.length,
        color: AppColors.accentWarning,
        students: high,
      ),
      _RiskTab(
        label: '🟡 Médio',
        count: medium.length,
        color: AppColors.chartColor3,
        students: medium,
      ),
    ].where((t) => t.count > 0).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.accentError),
                    const SizedBox(width: 8),
                    Text(
                      'Alunos em Risco',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${critical.length + high.length + medium.length} total',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (tabs.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Nenhum aluno em risco neste período.'),
                  ),
                )
              else
                Expanded(
                  child: DefaultTabController(
                    length: tabs.length,
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          tabs: tabs
                              .map((t) => Tab(
                                    child: Row(
                                      children: [
                                        Text(t.label),
                                        const SizedBox(width: 4),
                                        _CountBadge(
                                            count: t.count, color: t.color),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          labelColor: AppColors.primary,
                          unselectedLabelColor: context.colors.textMuted,
                          indicatorColor: AppColors.primary,
                        ),
                        Expanded(
                          child: TabBarView(
                            children: tabs
                                .map((t) => _RiskStudentList(
                                      students: t.students,
                                      scrollController: scrollController,
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _RiskTab {
  final String label;
  final int count;
  final Color color;
  final List<StudentMetricsItemDTO> students;

  _RiskTab({
    required this.label,
    required this.count,
    required this.color,
    required this.students,
  });
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _RiskStudentList extends StatelessWidget {
  final List<StudentMetricsItemDTO> students;
  final ScrollController scrollController;

  const _RiskStudentList({
    required this.students,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const Center(child: Text('Nenhum aluno nesta categoria.'));
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: students.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _AtRiskTile(student: students[i]),
    );
  }
}

class _AtRiskTile extends StatelessWidget {
  final StudentMetricsItemDTO student;

  const _AtRiskTile({required this.student});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OmniAvatar(name: student.userName, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.userName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (student.trainerName != null)
                  Text(
                    'Trainer: ${student.trainerName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textMuted,
                        ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _InfoChip(
                      'Adesão: ${student.adherenceRate.toStringAsFixed(0)}%',
                      AppColors.accentError,
                    ),
                    const SizedBox(width: 6),
                    _InfoChip(
                      'Inativo: ${student.daysInactive}d',
                      AppColors.accentWarning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Ação rápida
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Lembrete para ${student.userName} registrado.'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('Lembrete', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
