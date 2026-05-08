import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;

  const ResetPasswordScreen({Key? key, this.token}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _showPassword = false;

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
      _showError('As senhas não conferem');
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
        _showSuccess('Senha alterada com sucesso! Faça login com a nova senha.');
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
    final colors = isDark ? ThemeColors.dark : ThemeColors.light;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.login),
        ),
        title: const Text('Redefinir Senha'),
        elevation: 0,
        backgroundColor: colors.primaryColor,
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
                    Icons.lock_outline,
                    size: 80,
                    color: colors.primaryColor,
                  ),
                ),
                const SizedBox(height: 32),

                // Título
                Text(
                  'Crie uma Nova Senha',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Descrição
                Text(
                  'Sua nova senha deve ter:\n• Mínimo 8 caracteres\n• Letra maiúscula e minúscula\n• Número e caractere especial',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Campo nova senha
                TextField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Sua nova senha',
                    labelText: 'Nova Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colors.backgroundColor,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // Indicador de força
                if (_passwordController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildPasswordStrengthIndicator(),
                  ),

                // Campo confirmar senha
                TextField(
                  controller: _confirmController,
                  enabled: !_isLoading,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: 'Confirme sua nova senha',
                    labelText: 'Confirmar Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colors.backgroundColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Botão redefinir
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
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
                            'Redefinir Senha',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildPasswordStrengthIndicator() {
    final password = _passwordController.text;
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
