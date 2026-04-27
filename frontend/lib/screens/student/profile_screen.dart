import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
            return const Center(
              child: CircularProgressIndicator(),
            );
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

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(user),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildStatsCards(user),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildBodyDataSection(user),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildActivityLevelSection(),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSettingsSection(),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentError,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _handleLogout(context),
                        child: Text(
                          '↩️ Sair da Conta',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserResponse user) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  user.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            delay: const Duration(milliseconds: 100),
            child: Column(
              children: [
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(UserResponse user) {
    return Row(
      children: [
        Expanded(
          child: FadeInLeft(
            duration: const Duration(milliseconds: 300),
            delay: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.scale, color: AppColors.primary, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    user.imc.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'IMC — ${user.imcLabel}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FadeInRight(
            duration: const Duration(milliseconds: 300),
            delay: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_fire_department, color: AppColors.primary, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    user.tmb.toString(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'TMB (kcal/dia)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyDataSection(UserResponse user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Dados Corporais',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Icon(Icons.edit, color: AppColors.textMuted, size: 18),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildDataRow('Nome', user.name),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildDataRowCompact('Peso (kg)', user.weight.toStringAsFixed(1))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDataRowCompact('Altura (cm)', user.height.toStringAsFixed(0))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildDataRowCompact('Idade', user.age.toString())),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDataRowCompact('Sexo', user.role == 'male' ? 'Masculino' : 'Feminino')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDataRowCompact(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildActivityLevelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nível de Atividade',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Moderado',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configurações',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSettingRow('Privacidade', Icons.privacy_tip_outlined),
              Divider(height: 1, color: AppColors.border),
              _buildSettingRow('Notificações', Icons.notifications_outlined),
              Divider(height: 1, color: AppColors.border),
              _buildSettingRow('Sobre', Icons.info_outlined),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }

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
}
