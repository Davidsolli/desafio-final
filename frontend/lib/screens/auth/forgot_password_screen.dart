import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';

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

  void _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Por favor, insira seu email');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final authProvider = context.read<AuthProvider>();
      await authProvider.forgotPassword(email: email);

      if (mounted) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Erro ao processar solicitação');
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
          onPressed: () => context.pop(),
        ),
        title: const Text('Recuperar Senha'),
        elevation: 0,
        backgroundColor: colors.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: _emailSent ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ícone
        Container(
          width: double.infinity,
          alignment: Alignment.center,
          child: Icon(
            Icons.mail_outline,
            size: 80,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 32),

        // Título
        Text(
          'Esqueceu sua senha?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Descrição
        Text(
          'Insira seu email e enviaremos instruções para redefinir sua senha.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 32),

        // Campo de email
        TextField(
          controller: _emailController,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'seu@email.com',
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: colors.background,
          ),
        ),
        const SizedBox(height: 24),

        // Botão enviar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleForgotPassword,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: colors.primary,
              disabledBackgroundColor: colors.primary.withOpacity(0.5),
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
                    'Enviar Instruções',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Link: voltar ao login
        Container(
          width: double.infinity,
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: Text(
              'Voltar ao Login',
              style: TextStyle(color: colors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Ícone sucesso
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle,
            size: 40,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 24),

        // Título
        Text(
          'Email Enviado!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Descrição
        Text(
          'Se uma conta existe com este email, você receberá instruções para redefinir sua senha em breve.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Aviso
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '⏰ O link expira em 60 minutos',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.orange.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),

        // Botão voltar ao login
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go(AppRoutes.login),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Voltar ao Login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
