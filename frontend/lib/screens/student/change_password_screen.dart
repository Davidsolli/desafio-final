import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

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
      _showError('As novas senhas não conferem');
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
                // Informação
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
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
                          'Após alterar sua senha, você será desconectado em todos os dispositivos.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Senha atual
                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: 'Senha Atual',
                  hint: 'Sua senha atual',
                  obscure: _obscureCurrent,
                  onToggle: () {
                    setState(() => _obscureCurrent = !_obscureCurrent);
                  },
                ),
                const SizedBox(height: 20),

                // Nova senha
                _buildPasswordField(
                  controller: _newPasswordController,
                  label: 'Nova Senha',
                  hint: 'Sua nova senha',
                  obscure: _obscureNew,
                  onToggle: () {
                    setState(() => _obscureNew = !_obscureNew);
                  },
                ),
                const SizedBox(height: 8),

                // Indicador de força
                if (_newPasswordController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildPasswordStrengthIndicator(),
                  ),

                // Confirmar nova senha
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar Nova Senha',
                  hint: 'Confirme sua nova senha',
                  obscure: _obscureConfirm,
                  onToggle: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
                const SizedBox(height: 24),

                // Botão confirmar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleChangePassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: colors.primaryColor,
                      disabledBackgroundColor: colors.primaryColor.withOpacity(0.5),
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
                                theme.brightness == Brightness.dark ? Colors.white : Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Alterar Senha',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

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
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = isDark ? ThemeColors.dark : ThemeColors.light;

    return TextField(
      controller: controller,
      enabled: !_isLoading,
      obscureText: obscure,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: colors.backgroundColor,
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _newPasswordController.text;
    final isStrong = _isPasswordStrong(password);

    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: isStrong ? 1.0 : 0.3,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              isStrong ? Colors.green : Colors.red,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          isStrong ? '✓ Forte' : '✗ Fraca',
          style: TextStyle(
            color: isStrong ? Colors.green : Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
