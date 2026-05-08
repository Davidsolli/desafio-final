import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

class OmniProgressBar extends StatelessWidget {
  final double value;
  final String? label;
  final String? trailingLabel;
  final double height;
  final Color? progressColor;

  const OmniProgressBar({
    Key? key,
    required this.value,
    this.label,
    this.trailingLabel,
    this.height = 6,
    this.progressColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    final effectiveColor = progressColor ?? AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || trailingLabel != null) ...[
          Row(
            children: [
              if (label != null)
                Text(
                  label!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
              const Spacer(),
              if (trailingLabel != null)
                Text(
                  trailingLabel!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: clampedValue,
            minHeight: height,
            backgroundColor: effectiveColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
          ),
        ),
      ],
    );
  }
}
