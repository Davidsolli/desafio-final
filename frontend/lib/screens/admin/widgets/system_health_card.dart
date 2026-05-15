import 'package:flutter/material.dart';
import '../../../models/admin_metrics_models.dart';
import '../../../shared/widgets/omni_card.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';

class SystemHealthCard extends StatelessWidget {
  final SystemMetricsDTO data;

  const SystemHealthCard({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ratioColor = _ratioColor(data.dauMauRatio);
    final ratioLabel = _ratioLabel(data.dauMauRatio);

    return OmniCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.show_chart_rounded,
            title: 'Saúde do Sistema',
            subtitle: 'Últimos ${data.periodDays} dias',
          ),
          const SizedBox(height: 12),
          // DAU/MAU ratio destacado
          _RatioBadge(
            ratio: data.dauMauRatio,
            label: ratioLabel,
            color: ratioColor,
          ),
          const SizedBox(height: 14),
          // Grid 2×3
          _MetricsGrid(
            tiles: [
              _MetricTile('DAU', '${data.dau}', Icons.person_outline),
              _MetricTile('MAU', '${data.mau}', Icons.people_outline),
              _MetricTile(
                  'Novos Usuários', '${data.newUsersInPeriod}', Icons.add_circle_outline),
              _MetricTile(
                  'Treinos Feitos', '${data.totalWorkoutsCompleted}', Icons.fitness_center_outlined),
              _MetricTile(
                  'Logs de Dieta', '${data.totalDietLogs}', Icons.restaurant_outlined),
              _MetricTile(
                  'Trainers', '${data.totalTrainers}', Icons.sports_outlined),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Chatbot adoção (linha única, expandida)
          _ChatbotStat(
            label: 'Chatbot Adoção',
            value: '${data.chatbotAdoptionRate.toStringAsFixed(1)}%',
            icon: Icons.smart_toy_outlined,
            color: AppColors.accentInfo,
          ),
        ],
      ),
    );
  }

  Color _ratioColor(double ratio) {
    if (ratio >= 0.5) return AppColors.accentSuccess;
    if (ratio >= 0.3) return AppColors.accentWarning;
    return AppColors.accentError;
  }

  String _ratioLabel(double ratio) {
    if (ratio >= 0.5) return 'Excelente';
    if (ratio >= 0.3) return 'Bom';
    return 'Em Risco';
  }
}

class _RatioBadge extends StatelessWidget {
  final double ratio;
  final String label;
  final Color color;

  const _RatioBadge({
    required this.ratio,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'DAU/MAU: ${ratio.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '· $label',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final List<_MetricTile> tiles;

  const _MetricsGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    // Usar Row/Column em vez de GridView evita o cálculo de aspect ratio
    // que causa BOTTOM OVERFLOWED quando o conteúdo do tile não cabe exatamente.
    final rows = <List<_MetricTile>>[];
    for (var i = 0; i < tiles.length; i += 3) {
      rows.add(tiles.sublist(i, (i + 3).clamp(0, tiles.length)));
    }
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) const SizedBox(width: 8),
                  Expanded(child: rows[r][c]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.colors.textMuted),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.textMuted,
                  fontSize: 10,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ChatbotStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ChatbotStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.colors.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.textMuted,
              ),
        ),
      ],
    );
  }
}
