import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';

class OmniSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const OmniSectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
          ),
        ],
      ],
    );

    if (action != null) {
      return Row(
        children: [
          titleColumn,
          const Spacer(),
          action!,
        ],
      );
    }

    return titleColumn;
  }
}
