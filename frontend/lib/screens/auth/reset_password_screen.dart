import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/index.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;

  const ResetPasswordScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError('Preencha todos os campos');
      return;
    }

    if (newPassword != confirmPassword) {
      _showError('As senhas não conferem');
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      return;
    }

    if (widget.token.isEmpty) {
      _showError('Token inválido. Use o link recebido no email.');
      return;
    }

    try {
      setState(() => _isLoading = true);
      await context.read<AuthProvider>().resetPassword(
            token: widget.token,
            newPassword: newPassword,
            confirmPassword: confirmPassword,
          );

      if (mounted) {
        context.go(
          AppRoutes.login,
          extra: {'successMessage': 'Senha redefinida com sucesso! Faça login com sua nova senha.'},
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        _showError(message.isNotEmpty ? message : 'Erro ao redefinir senha. Tente novamente.');
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokenInvalid = widget.token.isEmpty;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.asset('assets/images/logo-2.png'),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: tokenInvalid ? _buildInvalidTokenState() : _buildFormState(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Icon(
          Icons.lock_outlined,
          size: 56,
          color: context.colors.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Nova Senha',
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Escolha uma senha segura para sua conta.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requisitos da senha:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              _buildRequirement('Mínimo 8 caracteres'),
              _buildRequirement('Uma letra maiúscula (A-Z)'),
              _buildRequirement('Uma letra minúscula (a-z)'),
              _buildRequirement('Um número (0-9)'),
              _buildRequirement('Um caractere especial (@\$!%*?&_-)'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OmniTextField(
          controller: _newPasswordController,
          labelText: 'Nova Senha',
          hintText: '••••••••',
          obscureText: true,
          prefixIcon: Icons.lock_outlined,
        ),
        const SizedBox(height: 12),
        OmniTextField(
          controller: _confirmPasswordController,
          labelText: 'Confirmar Nova Senha',
          hintText: '••••••••',
          obscureText: true,
          prefixIcon: Icons.lock_outlined,
        ),
        const SizedBox(height: 20),
        OmniButton(
          text: 'Redefinir Senha',
          onPressed: _handleReset,
          isLoading: _isLoading,
          width: double.infinity,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go(AppRoutes.forgotPassword),
          child: Text(
            'Solicitar novo link',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 5, color: context.colors.textMuted),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textMuted,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvalidTokenState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Icon(
          Icons.error_outline,
          size: 64,
          color: context.colors.accentError,
        ),
        const SizedBox(height: 16),
        Text(
          'Link inválido',
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Este link de recuperação é inválido ou já expirou. Solicite um novo link.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        OmniButton(
          text: 'Solicitar novo link',
          onPressed: () => context.go(AppRoutes.forgotPassword),
          width: double.infinity,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: Text(
            'Voltar para o login',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}
