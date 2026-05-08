import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';

class OmniLoader extends StatelessWidget {
  final Color? color;
  final double size;

  const OmniLoader({
    Key? key,
    this.color,
    this.size = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spinnerColor = color ?? colors.primary;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
          strokeWidth: 3,
        ),
      ),
    );
  }
}
