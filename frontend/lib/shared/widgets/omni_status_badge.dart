import 'package:flutter/material.dart';

class OmniStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isPill;

  const OmniStatusBadge({
    Key? key,
    required this.label,
    required this.color,
    this.isPill = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(isPill ? 20 : 6),
        border: isPill ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
      ),
    );
  }
}
