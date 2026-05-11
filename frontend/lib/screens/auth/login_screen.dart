import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/index.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final successMessage = extra?['successMessage'] as String?;
    if (successMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validação básica
    if (email.isEmpty || password.isEmpty) {
      _showError('Email e senha são obrigatórios');
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Faz login usando AuthProvider
      final authProvider = context.read<AuthProvider>();
      await authProvider.login(
        email: email,
        password: password,
      );

      if (mounted) {
        final user = authProvider.user;
        _navigateByRole(user?.role ?? '');
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateByRole(String role) {
    if (!mounted) return;

    switch (role) {
      case 'personal_trainer':
        context.go(AppRoutes.trainerStudents);
        break;
      case 'admin':
        context.go(AppRoutes.adminDashboard);
        break;
      case 'client':
      default:
        context.go(AppRoutes.home);
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
            // Logo fixa no topo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.asset('assets/images/logo-2.png'),
            ),
            // Resto do conteúdo com scroll responsivo
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Título
                      Text(
                        'Entrar',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Acesse sua conta',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      OmniTextField(
                        controller: _emailController,
                        labelText: 'Email',
                        hintText: 'seu@email.com',
                        prefixIcon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 12),
                      OmniTextField(
                        controller: _passwordController,
                        labelText: 'Senha',
                        hintText: '••••••••',
                        obscureText: true,
                        prefixIcon: Icons.lock_outlined,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.go(AppRoutes.forgotPassword),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_reset_outlined,
                                size: 16,
                                color: context.colors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Esqueci minha senha',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: context.colors.primary,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                      decorationColor: context.colors.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OmniButton(
                        text: 'Entrar',
                        onPressed: _handleLogin,
                        isLoading: _isLoading,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 16),
                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: context.colors.textSecondary.withValues(alpha: 0.3),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'OU',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: context.colors.textSecondary.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OmniButton(
                        text: 'Tenho um Código de Acesso',
                        onPressed: () => context.go(AppRoutes.inviteCode),
                        isOutlined: true,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
