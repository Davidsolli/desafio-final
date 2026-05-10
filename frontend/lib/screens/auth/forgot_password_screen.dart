import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/index.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendInstructions() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Informe seu email');
      return;
    }

    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email)) {
      _showError('Informe um email válido');
      return;
    }

    try {
      setState(() => _isLoading = true);
      await context.read<AuthProvider>().forgotPassword(email: email);
      if (mounted) {
        setState(() => _emailSent = true);
      }
    } catch (e) {
      if (mounted) {
        _showError('Erro ao enviar instruções. Verifique sua conexão.');
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  child: _emailSent ? _buildSuccessState() : _buildFormState(),
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
          Icons.lock_reset_outlined,
          size: 56,
          color: context.colors.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Esqueceu sua senha?',
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Informe seu email e enviaremos um link para você criar uma nova senha.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OmniTextField(
          controller: _emailController,
          labelText: 'Email',
          hintText: 'seu@email.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        OmniButton(
          text: 'Enviar Instruções',
          onPressed: _handleSendInstructions,
          isLoading: _isLoading,
          width: double.infinity,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: Text(
            'Voltar para o login',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: context.colors.accentSuccess,
        ),
        const SizedBox(height: 16),
        Text(
          'Verifique seu email',
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Se existir uma conta com o email informado, você receberá as instruções de recuperação em instantes.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Não esqueça de verificar a pasta de spam.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textMuted,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        OmniButton(
          text: 'Voltar para o login',
          onPressed: () => context.go(AppRoutes.login),
          width: double.infinity,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _emailSent = false;
              _emailController.clear();
            });
          },
          child: Text(
            'Tentar outro email',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}
