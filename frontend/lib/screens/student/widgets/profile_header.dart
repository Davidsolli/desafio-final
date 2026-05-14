import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../theme/theme_colors.dart';
import '../../../../services/user_service.dart';
import '../../../../widgets/profile_photo_avatar.dart';

class ProfileHeader extends StatelessWidget {
  final UserResponse user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return FadeInDown(
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          ProfilePhotoAvatar(
            userId: user.id,
            initial: user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            size: 80,
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
          ),
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
