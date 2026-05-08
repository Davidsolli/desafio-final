import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

class OmniStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final String? unit;
  final Color? iconColor;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool isSelected;

  const OmniStatCard({
    Key? key,
    required this.value,
    required this.label,
    this.icon,
    this.unit,
    this.iconColor,
    this.valueColor,
    this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.primary;
    final resolvedBorderColor = isSelected ? AppColors.primary : context.colors.border;
    final resolvedBgColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.08)
        : context.colors.surface;

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: resolvedBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: resolvedBorderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: effectiveIconColor),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                    ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  unit!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.textMuted,
                ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
