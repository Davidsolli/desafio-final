import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/theme_colors.dart';
import '../../../../theme/theme_provider.dart';
import '../../../../routes/app_routes.dart';
import '../../../../providers/user_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../shared/widgets/change_password_dialog.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar saída'),
        content: const Text('Tem certeza que deseja sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      if (mounted) {
        try {
          await context.read<AuthProvider>().logout();
          if (mounted) {
            context.read<UserProvider>().clearUser();
            context.go(AppRoutes.login);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao fazer logout: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    return Column(
      children: [
        // ── Toggle de Tema ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border.all(color: context.colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aparência',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      isDark ? 'Tema escuro ativo' : 'Tema claro ativo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isDark,
                activeColor: AppColors.primary,
                onChanged: (_) => themeProvider.toggleTheme(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Minha Assinatura ──────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => context.push(AppRoutes.subscription),
            icon: const Icon(Icons.card_membership_outlined, color: AppColors.primary),
            label: Text(
              'Minha Assinatura',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── Alterar Senha ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: context.colors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final userProvider = context.read<UserProvider>();
              showDialog(
                context: context,
                builder: (_) => ChangePasswordDialog(
                  onSubmit: (current, newPass, confirm) => userProvider.changePassword(
                    currentPassword: current,
                    newPassword: newPass,
                    confirmPassword: confirm,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.lock_outline, color: AppColors.primary),
            label: Text(
              'Alterar Senha',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── Logout ────────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentError,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: Text(
              'Sair da Conta',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
