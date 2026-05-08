import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';

class OmniAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;

  const OmniAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: backgroundColor ?? colors.background,
      elevation: 0,
      centerTitle: false,
      leading: showBackButton
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : null,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
