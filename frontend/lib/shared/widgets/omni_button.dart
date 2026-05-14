import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';
import 'omni_loader.dart';

class OmniButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final double? width;
  final double? height;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;

  const OmniButton({
    super.key,
    this.text = '',
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.width,
    this.height,
    this.icon,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final buttonColor = color ?? colors.primary;

    final effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    final child = isLoading
        ? OmniLoader(color: isOutlined ? buttonColor : Colors.white, size: 20)
        : icon != null
            ? Icon(icon, size: 24)
            : Text(text, style: TextStyle(color: isOutlined ? buttonColor : null, fontSize: 16, fontWeight: FontWeight.w600));

    if (isOutlined) {
      return SizedBox(
        width: width,
        height: height ?? 48,
        child: OutlinedButton(
          onPressed: (isLoading || onPressed == null) ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: buttonColor, width: 2),
            padding: effectivePadding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height ?? 48,
      child: ElevatedButton(
        onPressed: (isLoading || onPressed == null) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: effectivePadding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          disabledBackgroundColor: colors.textMuted.withValues(alpha: 0.3),
        ),
        child: child,
      ),
    );
  }
}
