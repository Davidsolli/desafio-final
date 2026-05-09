import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/password_input_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  PasswordStrength _newPasswordStrength = PasswordStrength.empty;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleChangePassword() async {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showError('Por favor, preencha todos os campos');
      return;
    }

    if (newPass != confirm) {
      _clearNewPasswordFields();
      _showError('As novas senhas não conferem. Os campos foram limpos.');
      return;
    }

    if (!_isPasswordStrong(newPass)) {
      _showError('Senha fraca. Mínimo 8 caracteres, maiúscula, minúscula, número e caractere especial');
      return;
    }

    if (current == newPass) {
      _showError('A nova senha deve ser diferente da atual');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final authProvider = context.read<AuthProvider>();
      await authProvider.changePassword(
        currentPassword: current,
        newPassword: newPass,
        confirmPassword: confirm,
      );

      if (mounted) {
        _showSuccess('Senha alterada com sucesso! Você será desconectado.');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          await authProvider.logout();
          if (mounted) {
            context.go(AppRoutes.login);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(_parseError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearNewPasswordFields() {
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  bool _isPasswordStrong(String password) {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_\-])[a-zA-Z\d@$!%*?&_\-]{8,}$',
    );
    return regex.hasMatch(password);
  }

  String _parseError(dynamic error) {
    final message = error.toString();
    if (message.contains('incorreta')) return 'Senha atual incorreta';
    if (message.contains('diferente')) return 'Nova senha deve ser diferente da atual';
    if (message.contains('não conferem')) return 'As senhas não conferem';
    if (message.contains('fraca')) return 'Senha não atende requisitos';
    return 'Erro ao alterar senha. Tente novamente.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = isDark ? ThemeColors.dark : ThemeColors.light;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Alterar Senha'),
        elevation: 0,
        backgroundColor: colors.primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone
                Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: colors.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Informação importante
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Por segurança, você será desconectado em todos os dispositivos.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Senha atual
                PasswordInputField(
                  controller: _currentPasswordController,
                  label: 'Senha Atual',
                  hintText: 'Digite sua senha atual',
                  prefixIcon: Icons.lock_outline,
                  enabled: !_isLoading,
                  primaryColor: colors.primaryColor,
                  backgroundColor: colors.backgroundColor,
                  textSecondaryColor: colors.textSecondary,
                ),
                const SizedBox(height: 24),

                // Nova senha
                PasswordInputField(
                  controller: _newPasswordController,
                  label: 'Nova Senha',
                  hintText: 'Digite sua nova senha (mín. 8 caracteres)',
                  prefixIcon: Icons.lock_outline,
                  enabled: !_isLoading,
                  showStrengthIndicator: true,
                  strengthDescription: '• Mínimo 8 caracteres\n• Maiúscula e minúscula\n• Número e caractere especial (@\$!%*?&_-)',
                  onStrengthChanged: (strength) {
                    setState(() => _newPasswordStrength = strength);
                  },
                  primaryColor: colors.primaryColor,
                  backgroundColor: colors.backgroundColor,
                  textSecondaryColor: colors.textSecondary,
                ),
                const SizedBox(height: 24),

                // Confirmar nova senha
                PasswordInputField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar Nova Senha',
                  hintText: 'Confirme sua nova senha',
                  prefixIcon: Icons.lock_outline,
                  enabled: !_isLoading,
                  isConfirmation: true,
                  primaryColor: colors.primaryColor,
                  backgroundColor: colors.backgroundColor,
                  textSecondaryColor: colors.textSecondary,
                ),
                const SizedBox(height: 12),

                // Validação de confirmação em tempo real
                if (_newPasswordController.text.isNotEmpty &&
                    _confirmPasswordController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildConfirmationStatus(),
                  ),

                const SizedBox(height: 16),

                // Botão alterar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleChangePassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: colors.primaryColor,
                      disabledBackgroundColor:
                          colors.primaryColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Alterar Senha',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botão cancelar
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationStatus() {
    final match = _newPasswordController.text == _confirmPasswordController.text;
    final color = match ? Colors.green : Colors.red;
    final icon = match ? Icons.check_circle : Icons.cancel;
    final text = match ? 'Senhas conferem' : 'Senhas não conferem';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
