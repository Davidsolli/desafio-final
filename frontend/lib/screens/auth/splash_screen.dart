import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';

/// Rotas públicas acessíveis sem autenticação via deep link (ex: link de email).
const _publicDeepLinks = [
  AppRoutes.resetPassword,
  AppRoutes.forgotPassword,
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.inviteCode,
];

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final authProvider = context.read<AuthProvider>();

    // Dispara a verificação de sessão e um timer mínimo de 3s (para a animação)
    // O Future.wait aguardará a tarefa que for mais demorada.
    await Future.wait([
      authProvider.checkAuthState(),
      Future.delayed(const Duration(seconds: 3)),
    ]);

    if (!mounted) return;

    // Se o app foi aberto via deep link público (ex: /reset-password?token=... do email),
    // o GoRouter já navegou para essa rota. Não sobrescrever com redirect para login.
    if (kIsWeb) {
      final browserPath = Uri.base.path;
      if (_publicDeepLinks.any((r) => browserPath.startsWith(r))) {
        // Garantir que o GoRouter também reflita a rota correta com query params
        final destination = Uri.base.query.isNotEmpty
            ? '${Uri.base.path}?${Uri.base.query}'
            : Uri.base.path;
        context.go(destination);
        return;
      }
    }

    if (authProvider.isAuthenticated && authProvider.user != null) {
      _navigateByRole(authProvider.user!.role);
    } else {
      context.go(AppRoutes.login);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BounceInDown(
              duration: const Duration(milliseconds: 600),
              child: Image.asset('assets/images/logo-2.png'),
            ),
            const SizedBox(height: 32),

            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Text(
                'Seu treino, nutrição e evolução em um só lugar.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
