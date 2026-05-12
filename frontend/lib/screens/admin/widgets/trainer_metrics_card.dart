import 'package:flutter/material.dart';
import '../../../models/admin_metrics_models.dart';
import '../../../shared/widgets/omni_card.dart';
import '../../../shared/widgets/omni_avatar.dart';
import '../../../shared/widgets/omni_empty_state.dart';
import '../../../shared/widgets/omni_loader.dart';
import '../../../shared/widgets/omni_error_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';

enum _TrainerSort { students, health, conversion }

class TrainerMetricsCard extends StatefulWidget {
  final PaginatedTrainerMetricsDTO? data;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  const TrainerMetricsCard({
    Key? key,
    required this.data,
    required this.isLoading,
    this.error,
    this.onRetry,
  }) : super(key: key);

  @override
  State<TrainerMetricsCard> createState() => _TrainerMetricsCardState();
}

class _TrainerMetricsCardState extends State<TrainerMetricsCard> {
  _TrainerSort _sortBy = _TrainerSort.students;

  List<TrainerMetricsItemDTO> _sortedTrainers(List<TrainerMetricsItemDTO> list) {
    final sorted = [...list];
    switch (_sortBy) {
      case _TrainerSort.students:
        sorted.sort((a, b) => b.totalStudents.compareTo(a.totalStudents));
      case _TrainerSort.health:
        sorted.sort((a, b) => b.portfolioHealth.compareTo(a.portfolioHealth));
      case _TrainerSort.conversion:
        sorted.sort((a, b) => b.conversionRate.compareTo(a.conversionRate));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return OmniCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.sports_outlined, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          'Personal Trainers',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (widget.data != null)
          _SortButton(
            current: _sortBy,
            onChanged: (v) => setState(() => _sortBy = v),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.isLoading) {
      return const SizedBox(height: 120, child: Center(child: OmniLoader()));
    }
    if (widget.error != null) {
      return OmniErrorState(
        message: widget.error!,
        onRetry: widget.onRetry,
      );
    }
    final data = widget.data;
    if (data == null || data.data.isEmpty) {
      return const OmniEmptyState(icon: Icons.person_off, title: 'Nenhum trainer encontrado.');
    }

    final sorted = _sortedTrainers(data.data);
    return Column(
      children: sorted.asMap().entries.map((entry) {
        return _TrainerRankTile(
          rank: entry.key + 1,
          trainer: entry.value,
        );
      }).toList(),
    );
  }
}

class _SortButton extends StatelessWidget {
  final _TrainerSort current;
  final ValueChanged<_TrainerSort> onChanged;

  const _SortButton({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final labels = {
      _TrainerSort.students: 'Alunos',
      _TrainerSort.health: 'Saúde',
      _TrainerSort.conversion: 'Conversão',
    };
    return PopupMenuButton<_TrainerSort>(
      initialValue: current,
      onSelected: onChanged,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ordenar: ${labels[current]}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.textMuted,
                ),
          ),
          Icon(Icons.unfold_more, size: 14, color: context.colors.textMuted),
        ],
      ),
      itemBuilder: (_) => labels.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
    );
  }
}

class _TrainerRankTile extends StatelessWidget {
  final int rank;
  final TrainerMetricsItemDTO trainer;

  const _TrainerRankTile({required this.rank, required this.trainer});

  Color _healthColor(double health) {
    if (health >= 80) return AppColors.accentSuccess;
    if (health >= 50) return AppColors.accentWarning;
    return AppColors.accentError;
  }

  @override
  Widget build(BuildContext context) {
    final healthColor = _healthColor(trainer.portfolioHealth);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ranking badge
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : context.colors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: rank <= 3
                              ? AppColors.primary
                              : context.colors.textMuted,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OmniAvatar(name: trainer.trainerName, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer.trainerName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${trainer.totalStudents} alunos · ${trainer.atRiskStudents} em risco',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '${trainer.portfolioHealth.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: healthColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Portfolio health bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (trainer.portfolioHealth / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: healthColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(healthColor),
            ),
          ),
          const SizedBox(height: 4),
          // Stats row
          Row(
            children: [
              _SmallStat(
                'Conversão',
                '${trainer.conversionRate.toStringAsFixed(0)}%',
                AppColors.accentInfo,
              ),
              const SizedBox(width: 12),
              _SmallStat(
                'Aderência média',
                '${trainer.avgStudentAdherence.toStringAsFixed(0)}%',
                AppColors.primary,
              ),
              const SizedBox(width: 12),
              _SmallStat(
                'Convites',
                '${trainer.invitesUsed}/${trainer.invitesGenerated}',
                context.colors.textMuted,
              ),
            ],
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SmallStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.textMuted,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}
