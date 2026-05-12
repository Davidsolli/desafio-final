import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/admin_metrics_models.dart';
import '../../../models/admin_models.dart';
import '../../../providers/admin_metrics_provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../shared/widgets/omni_avatar.dart';
import '../../../shared/widgets/omni_card.dart';
import '../../../shared/widgets/omni_empty_state.dart';
import '../../../shared/widgets/omni_error_state.dart';
import '../../../shared/widgets/omni_loader.dart';
import '../../../shared/widgets/omni_status_badge.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import 'at_risk_students_sheet.dart';

class StudentMetricsCard extends StatefulWidget {
  final PaginatedStudentMetricsDTO? data;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onLoadMore;
  final Future<void> Function(String?) onTrainerFilterChanged;

  const StudentMetricsCard({
    Key? key,
    required this.data,
    required this.isLoading,
    required this.hasMore,
    this.error,
    this.onRetry,
    this.onLoadMore,
    required this.onTrainerFilterChanged,
  }) : super(key: key);

  @override
  State<StudentMetricsCard> createState() => _StudentMetricsCardState();
}

class _StudentMetricsCardState extends State<StudentMetricsCard> {
  String _searchQuery = '';
  String? _riskFilter; // null = todos

  List<StudentMetricsItemDTO> get _filtered {
    final items = widget.data?.data ?? [];
    return items.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.userName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRisk =
          _riskFilter == null || s.riskLevel == _riskFilter;
      return matchesSearch && matchesRisk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return OmniCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          if (widget.data != null) ...[
            _buildSummaryGrid(context),
            const SizedBox(height: 8),
            _buildRiskChips(context),
            const SizedBox(height: 10),
          ],
          _buildSearchAndActions(context),
          const SizedBox(height: 10),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final trainers = context.watch<AdminProvider>().trainers;
    final selectedTrainerId =
        context.watch<AdminMetricsProvider>().selectedTrainerId;

    return Row(
      children: [
        const Icon(Icons.school_outlined, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          'Alunos',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        // Filtro de trainer
        _TrainerFilterDropdown(
          trainers: trainers,
          selectedId: selectedTrainerId,
          onChanged: widget.onTrainerFilterChanged,
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(BuildContext context) {
    final s = widget.data!.summary;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        _SummaryTile(
          '${s.totalStudents}',
          'Total de Alunos',
          AppColors.primary,
          Icons.group_outlined,
        ),
        _SummaryTile(
          '${s.avgAdherenceRate.toStringAsFixed(1)}%',
          'Aderência Média',
          AppColors.accentInfo,
          Icons.trending_up,
        ),
        _SummaryTile(
          '${s.totalAtRisk}',
          'Em Risco',
          AppColors.accentError,
          Icons.warning_amber_outlined,
        ),
        _SummaryTile(
          '${s.highAdherenceCount}',
          'Alta Adesão',
          AppColors.accentSuccess,
          Icons.star_outline,
        ),
      ],
    );
  }

  Widget _buildRiskChips(BuildContext context) {
    final s = widget.data!.summary;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _RiskChip(
            label: 'Todos',
            count: s.totalStudents,
            color: context.colors.textMuted,
            isSelected: _riskFilter == null,
            onTap: () => setState(() => _riskFilter = null),
          ),
          const SizedBox(width: 6),
          _RiskChip(
            label: '🔴 Crítico',
            count: s.atRiskCritical,
            color: AppColors.accentError,
            isSelected: _riskFilter == 'critical',
            onTap: () => setState(
                () => _riskFilter = _riskFilter == 'critical' ? null : 'critical'),
          ),
          const SizedBox(width: 6),
          _RiskChip(
            label: '🟠 Alto',
            count: s.atRiskHigh,
            color: AppColors.accentWarning,
            isSelected: _riskFilter == 'high',
            onTap: () => setState(
                () => _riskFilter = _riskFilter == 'high' ? null : 'high'),
          ),
          const SizedBox(width: 6),
          _RiskChip(
            label: '🟡 Médio',
            count: s.atRiskMedium,
            color: AppColors.chartColor3,
            isSelected: _riskFilter == 'medium',
            onTap: () => setState(
                () => _riskFilter = _riskFilter == 'medium' ? null : 'medium'),
          ),
          const SizedBox(width: 6),
          _RiskChip(
            label: '🟢 Baixo',
            count: s.atRiskLow,
            color: AppColors.accentSuccess,
            isSelected: _riskFilter == 'low',
            onTap: () => setState(
                () => _riskFilter = _riskFilter == 'low' ? null : 'low'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar aluno...',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.colors.border),
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(width: 8),
        // Ver em Risco
        if (widget.data != null && widget.data!.summary.totalAtRisk > 0)
          OutlinedButton.icon(
            icon: const Icon(Icons.warning_amber_outlined, size: 16),
            label: Text('${widget.data!.summary.totalAtRisk} em risco'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentError,
              side: const BorderSide(color: AppColors.accentError),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onPressed: () => _showAtRiskSheet(context),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.isLoading && widget.data == null) {
      return const SizedBox(height: 120, child: Center(child: OmniLoader()));
    }
    if (widget.error != null && widget.data == null) {
      return OmniErrorState(
        message: widget.error!,
        onRetry: widget.onRetry,
      );
    }

    final items = _filtered;
    if (items.isEmpty) {
      return const OmniEmptyState(icon: Icons.person_off, title: 'Nenhum aluno encontrado.');
    }

    return Column(
      children: [
        ...items.map((s) => _StudentTile(student: s)),
        if (widget.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton(
                onPressed:
                    widget.isLoading ? null : widget.onLoadMore,
                child: widget.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ver mais'),
              ),
            ),
          ),
      ],
    );
  }

  void _showAtRiskSheet(BuildContext context) {
    final students = widget.data?.data ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AtRiskStudentsSheet(students: students),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _TrainerFilterDropdown extends StatelessWidget {
  final List<AdminUserDTO> trainers;
  final String? selectedId;
  final Future<void> Function(String?) onChanged;

  const _TrainerFilterDropdown({
    required this.trainers,
    this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      initialValue: selectedId,
      onSelected: onChanged,
      tooltip: 'Filtrar por trainer',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list, size: 16, color: context.colors.textMuted),
          const SizedBox(width: 4),
          Text(
            selectedId == null
                ? 'Todos'
                : trainers
                    .firstWhere(
                      (t) => t.id == selectedId,
                      orElse: () =>
                          AdminUserDTO(id: '', name: '?', email: '', role: '', isActive: true, createdAt: DateTime.now()),
                    )
                    .name,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
      itemBuilder: (_) => [
        const PopupMenuItem<String?>(value: null, child: Text('Todos os trainers')),
        ...trainers.map((t) => PopupMenuItem<String?>(
              value: t.id,
              child: Text(t.name),
            )),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const _SummaryTile(this.value, this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.textMuted,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RiskChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : context.colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isSelected ? color : context.colors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final StudentMetricsItemDTO student;

  const _StudentTile({required this.student});

  Color _adherenceColor(String category) {
    switch (category) {
      case 'high':
        return AppColors.accentSuccess;
      case 'medium':
        return AppColors.accentWarning;
      default:
        return AppColors.accentError;
    }
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'critical':
        return AppColors.accentError;
      case 'high':
        return AppColors.accentWarning;
      case 'medium':
        return AppColors.chartColor3;
      default:
        return AppColors.accentSuccess;
    }
  }

  String _riskLabel(String level) {
    switch (level) {
      case 'critical':
        return 'Crítico';
      case 'high':
        return 'Alto';
      case 'medium':
        return 'Médio';
      default:
        return 'Baixo';
    }
  }

  String _lastActivityText() {
    if (student.lastActivity == null) return 'Sem atividade';
    final days = student.daysInactive;
    if (days == 0) return 'Hoje';
    if (days == 1) return 'Ontem';
    return 'Há $days dias';
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _adherenceColor(student.adherenceCategory);
    final riskColor = _riskColor(student.riskLevel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OmniAvatar(name: student.userName, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.userName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _lastActivityText(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OmniStatusBadge(
                label: _riskLabel(student.riskLevel),
                color: riskColor,
                isPill: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (student.adherenceRate / 100).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: barColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${student.adherenceRate.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Treinos',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.textMuted,
                          ),
                    ),
                    Text(
                      '${student.sessionsCompleted}/${student.sessionsTotal}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logs de Dieta',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.textMuted,
                          ),
                    ),
                    Text(
                      '${student.dietLogsCount}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              if (student.goalProgress != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progresso Meta',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: context.colors.textMuted,
                            ),
                      ),
                      Text(
                        '${student.goalProgress!.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentSuccess,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 14),
        ],
      ),
    );
  }
}
