import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

class OmniInfoChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? textColor;
  final VoidCallback? onTap;

  const OmniInfoChip({
    Key? key,
    required this.label,
    this.icon,
    this.textColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? context.colors.textMuted;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: effectiveTextColor,
                ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: chip);
    }
    return chip;
  }
}
