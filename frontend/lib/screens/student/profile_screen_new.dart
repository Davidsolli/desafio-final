import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/user_provider.dart';

import 'widgets/profile_header.dart';
import 'widgets/profile_stats_cards.dart';
import 'widgets/profile_body_form.dart';
import 'widgets/profile_goals_section.dart';
import 'widgets/profile_achievements.dart';
import 'widgets/profile_settings.dart';

class ProfileScreenV2 extends StatefulWidget {
  const ProfileScreenV2({super.key});

  @override
  State<ProfileScreenV2> createState() => _ProfileScreenV2State();
}

class _ProfileScreenV2State extends State<ProfileScreenV2> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserProvider>().loadUser().catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar perfil: $e')),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          if (userProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.accentError),
                  const SizedBox(height: 16),
                  Text(userProvider.error ?? 'Erro ao carregar'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => userProvider.loadUser(),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          final user = userProvider.user;
          if (user == null) {
            return const Center(child: Text('Nenhum usuário carregado'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                ProfileHeader(user: user),
                const SizedBox(height: 24),
                ProfileStatsCards(user: user),
                const SizedBox(height: 24),
                ProfileBodyForm(user: user),
                const SizedBox(height: 24),
                const ProfileGoalsSection(),
                const SizedBox(height: 24),
                const ProfileAchievements(),
                const SizedBox(height: 24),
                const ProfileSettings(),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
