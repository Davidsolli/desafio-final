import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../theme/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/admin_models.dart';
import '../../shared/widgets/change_password_dialog.dart';
import '../../widgets/profile_photo_avatar.dart';

class TrainerProfile extends StatefulWidget {
  const TrainerProfile({super.key});

  @override
  State<TrainerProfile> createState() => _TrainerProfileState();
}

class _TrainerProfileState extends State<TrainerProfile> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _crefController;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _crefController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      await context.read<UserProvider>().loadUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  void _syncWithAuthProvider(AuthUser? user) {
    if (user != null && _lastUserId != user.id) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phoneWhatsapp ?? '';
      _lastUserId = user.id;
    }
  }

  Future<void> _handleSaveChanges(BuildContext context, UserProvider userProvider) async {
    try {
      final nameText = _nameController.text.trim();
      final phoneText = _phoneController.text.trim();

      await userProvider.updateUser(
        name: nameText,
        phoneWhatsapp: phoneText.isNotEmpty ? phoneText : null,
      );

      if (mounted) {
        context.read<AuthProvider>().updateUserProfile(
          name: nameText,
          phoneWhatsapp: phoneText.isNotEmpty ? phoneText : null,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Alterações salvas com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro ao salvar: ${userProvider.error}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _crefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        _syncWithAuthProvider(user);

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(user),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPersonalDataSection(),
                      const SizedBox(height: 24),
                      _buildNotificationTile(),
                      const SizedBox(height: 16),
                      _buildThemeToggle(),
                      const SizedBox(height: 16),
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
                                onSubmit: (current, newPass, confirm) =>
                                    userProvider.changePassword(
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
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.accentError, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final router = GoRouter.of(context);
                            await authProvider.logout();
                            router.go(AppRoutes.login);
                          },
                          child: Text('Sair da Conta',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.accentError, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(AuthUser? user) {
    final initial = (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?';
    final name = user?.name ?? '';
    final email = user?.email ?? '';
    final userId = user?.id ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          ProfilePhotoAvatar(
            userId: userId,
            initial: initial,
            size: 70,
            isCircle: false,
            borderRadius: 16,
            badgeSize: 24,
            badgeIconSize: 12,
            emptyDecoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
          Text(name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(email,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final role = context.read<AuthProvider>().user?.role ?? 'personal_trainer';
            final isPersonal = hasRole(role, 'personal_trainer');
            final isNutri = hasRole(role, 'nutritionist');
            final label = (isPersonal && isNutri)
                ? 'Personal + Nutricionista'
                : isNutri
                    ? 'Nutricionista'
                    : 'Personal Trainer';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPersonalDataSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Dados Pessoais',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('Nome', _nameController),
          const SizedBox(height: 12),
          _buildTextField('Email', _emailController, readOnly: true),
          const SizedBox(height: 12),
          _buildTextField('Telefone', _phoneController),
          const SizedBox(height: 12),
          _buildTextField('CREF', _crefController, hint: 'Ex: 012345-G/SP'),
          const SizedBox(height: 16),
          Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: userProvider.isLoading ? context.colors.textMuted : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: userProvider.isLoading
                      ? null
                      : () => _handleSaveChanges(context, userProvider),
                  child: userProvider.isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                            ),
                          ),
                        )
                      : Text('Salvar Alterações',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool readOnly = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.colors.textMuted),
            filled: true,
            fillColor: context.colors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.colors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: TextStyle(
            color: readOnly ? context.colors.textMuted : context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTile() {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.notificationsSettings),
      child: Container(
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
              child: const Icon(
                Icons.notifications_active_outlined,
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
                    'Configurações de Notificações',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    'Gerenciar alertas de alunos e fuso horário',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    return Container(
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
    );
  }
}
