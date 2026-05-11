import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import 'notifications_settings_client_screen.dart';
import 'notifications_settings_trainer_screen.dart';

/// Dispatcher de tela de configurações de notificação por role do usuário.
///
/// - `client` → `NotificationsSettingsClientScreen` (lembretes de treino,
///   refeição, novas fichas).
/// - `personal_trainer` → `NotificationsSettingsTrainerScreen` (alerta de
///   aluno inativo).
/// - `admin` → redireciona para o dashboard de admin (não recebe pushes).
///
/// Padrão espelhado em `screens/auth/splash_screen.dart` (Fase 4).
class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _redirectScheduled = false;

  void _scheduleAdminRedirect() {
    if (_redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.adminDashboard);
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;

    switch (role) {
      case 'client':
        return const NotificationsSettingsClientScreen();
      case 'personal_trainer':
        return const NotificationsSettingsTrainerScreen();
      case 'admin':
        _scheduleAdminRedirect();
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      default:
        // Não autenticado ou role inesperado — o router protege a rota,
        // mas mantemos um fallback visual para evitar tela branca.
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
    }
  }
}
