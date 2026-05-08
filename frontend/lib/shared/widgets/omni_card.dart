import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';

class OmniCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double? elevation;
  final double borderRadius;

  const OmniCard({
    Key? key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.borderRadius = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      color: backgroundColor ?? colors.surface,
      elevation: elevation ?? 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
