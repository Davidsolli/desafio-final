import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/health_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';

/// Card resumo de frequência cardíaca exibido na home do aluno.
/// Consome [HealthProvider] para exibir BPM médio do dia e indicar
/// se os dados vieram de um smartwatch/fitness tracker.
class HeartRateSummaryCard extends StatelessWidget {
  const HeartRateSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthProvider>(
      builder: (context, provider, _) {
        if (provider.state == HealthProviderState.unavailable) {
          return _UnavailableCard();
        }

        final isLoading = provider.state == HealthProviderState.loading ||
            provider.state == HealthProviderState.idle;

        final peakBpm = provider.peakHeartRateBpm;
        final isFromSmartwatch = provider.isFromSmartwatch;
        final sourceName = provider.smartwatchSourceName;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border.all(color: context.colors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FREQUÊNCIA CARDÍACA',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.5,
                            color: context.colors.textMuted,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isLoading)
                          Container(
                            width: 56,
                            height: 22,
                            decoration: BoxDecoration(
                              color: context.colors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        else
                          Text(
                            peakBpm > 0
                                ? '$peakBpm bpm'
                                : '— bpm',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        if (!isLoading && isFromSmartwatch) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: sourceName.isNotEmpty
                                ? sourceName
                                : 'Smartwatch',
                            child: const Icon(
                              Icons.watch,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                'pico do dia',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.favorite_border,
              color: context.colors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FREQUÊNCIA CARDÍACA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.5,
                        color: context.colors.textMuted,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Health Connect indisponível',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textMuted,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
