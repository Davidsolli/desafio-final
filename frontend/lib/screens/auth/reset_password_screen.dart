import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/password_input_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;

  const ResetPasswordScreen({Key? key, this.token}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  PasswordStrength _passwordStrength = PasswordStrength.empty;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final token = widget.token;

    if (token == null || token.isEmpty) {
      _showError('Token inválido. Verifique o link de email.');
      return;
    }

    if (password.isEmpty || confirm.isEmpty) {
      _showError('Por favor, preencha todos os campos');
      return;
    }

    if (password != confirm) {
      _clearPasswordFields();
      _showError('As senhas não conferem. Os campos foram limpos.');
      return;
    }

    if (!_isPasswordStrong(password)) {
      _showError('Senha fraca. Mínimo 8 caracteres, maiúscula, minúscula, número e caractere especial');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final authProvider = context.read<AuthProvider>();
      await authProvider.resetPassword(
        token: token,
        password: password,
        confirmPassword: confirm,
      );

      if (mounted) {
        _showSuccess('Senha redefinida com sucesso! Faça login com a nova senha.');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go(AppRoutes.login);
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

  void _clearPasswordFields() {
    _passwordController.clear();
    _confirmController.clear();
  }

  bool _isPasswordStrong(String password) {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_\-])[a-zA-Z\d@$!%*?&_\-]{8,}$',
    );
    return regex.hasMatch(password);
  }

  String _parseError(dynamic error) {
    final message = error.toString();
    if (message.contains('Token inválido')) return 'Token inválido ou expirado';
    if (message.contains('expirado')) return 'Token expirado';
    if (message.contains('já foi utilizado')) return 'Token já foi utilizado';
    if (message.contains('não conferem')) return 'As senhas não conferem';
    if (message.contains('fraca')) return 'Senha não atende requisitos';
    return 'Erro ao redefinir senha. Tente novamente.';
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
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.login),
        ),
        title: const Text('Redefinir Senha'),
        elevation: 0,
        backgroundColor: colors.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone
                Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock_reset,
                    size: 80,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 32),

                // Título
                Text(
                  'Redefinir Senha',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Descrição
                Text(
                  'Crie uma nova senha forte para sua conta.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Nova senha com indicador de força
                PasswordInputField(
                  controller: _passwordController,
                  label: 'Nova Senha',
                  hintText: 'Digite sua nova senha (mín. 8 caracteres)',
                  prefixIcon: Icons.lock_outline,
                  enabled: !_isLoading,
                  showStrengthIndicator: true,
                  strengthDescription: '• Mínimo 8 caracteres\n• Maiúscula e minúscula\n• Número e caractere especial (@\$!%*?&_-)',
                  onStrengthChanged: (strength) {
                    setState(() => _passwordStrength = strength);
                  },
                  primaryColor: colors.primary,
                  backgroundColor: colors.background,
                  textSecondaryColor: colors.textSecondary,
                ),
                const SizedBox(height: 24),

                // Confirmar senha
                PasswordInputField(
                  controller: _confirmController,
                  label: 'Confirmar Senha',
                  hintText: 'Confirme sua nova senha',
                  prefixIcon: Icons.lock_outline,
                  enabled: !_isLoading,
                  isConfirmation: true,
                  primaryColor: colors.primary,
                  backgroundColor: colors.background,
                  textSecondaryColor: colors.textSecondary,
                ),
                const SizedBox(height: 12),

                // Validação de confirmação em tempo real
                if (_passwordController.text.isNotEmpty &&
                    _confirmController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildConfirmationStatus(),
                  ),

                const SizedBox(height: 16),

                // Botão redefinir
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: colors.primary,
                      disabledBackgroundColor:
                          colors.primary.withOpacity(0.5),
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
                            'Redefinir Senha',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Link para voltar ao login
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => context.go(AppRoutes.login),
                    child: Text(
                      'Voltar ao Login',
                      style: TextStyle(color: colors.primary),
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
    final match = _passwordController.text == _confirmController.text;
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
