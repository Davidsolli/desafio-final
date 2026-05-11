import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class OmniAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool useGradient;

  const OmniAvatar({
    Key? key,
    required this.name,
    this.size = 44,
    this.useGradient = false,
  }) : super(key: key);

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: size * 0.4,
    );

    if (useGradient) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
        ),
        child: Center(
          child: Text(_initial, style: textStyle),
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary,
      child: Text(_initial, style: textStyle),
    );
  }
}
