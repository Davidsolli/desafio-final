import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';

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
        context.go(AppRoutes.trainerDashboard);
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
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BounceInDown(
              duration: const Duration(milliseconds: 600),
              child: Image.asset('assets/images/logo-2.png'),
            ),
            const SizedBox(height: 32),
            FadeInDown(
              delay: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  Text(
                    'OmniConnect',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Fitness',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Text(
                'Seu treino, nutrição e evolução em um só lugar.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
