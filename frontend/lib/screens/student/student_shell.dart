import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/step_provider.dart';
import '../../providers/health_provider.dart';
import '../../services/user_service.dart';

class StudentShell extends StatefulWidget {
  final Widget child;

  const StudentShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell>
    with WidgetsBindingObserver {
  bool _stepsInitialized = false;
  bool _healthInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStepProvider();
      _initHealthProvider();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      context.read<StepProvider>().onAppPaused();
      context.read<HealthProvider>().syncToBackend();
    }
  }

  Future<void> _initStepProvider() async {
    if (_stepsInitialized || kIsWeb) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    _stepsInitialized = true;

    // Buscar dados antropométricos para refinar o stride length
    double? heightCm;
    String? gender;
    try {
      final userService = context.read<UserService>();
      final me = await userService.getCurrentUser();
      heightCm = me.height > 0 ? me.height : null;
      gender = me.gender;
    } catch (_) {
      // Falhou; usa fallback de stride no provider.
    }

    if (!mounted) return;
    await context.read<StepProvider>().initialize(
          userId: user.id,
          heightCm: heightCm,
          gender: gender,
        );
  }

  Future<void> _initHealthProvider() async {
    if (_healthInitialized || kIsWeb) return;
    _healthInitialized = true;
    if (!mounted) return;
    await context.read<HealthProvider>().initialize();
  }

  int _getSelectedNavIndex(String currentPath) {
    if (currentPath.contains(AppRoutes.home)) return 0;
    if (currentPath.contains(AppRoutes.workouts)) return 1;
    if (currentPath.contains(AppRoutes.nutrition)) return 2;
    if (currentPath.contains(AppRoutes.chat)) return 3;
    if (currentPath.contains(AppRoutes.profile)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final selectedIndex = _getSelectedNavIndex(currentPath);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: widget.child,
      bottomNavigationBar: _buildBottomNav(selectedIndex),
    );
  }

  Widget _buildBottomNav(int selectedIndex) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          final routes = [
            AppRoutes.home,
            AppRoutes.workouts,
            AppRoutes.nutrition,
            AppRoutes.chat,
            AppRoutes.profile,
          ];
          context.go(routes[index]);
        },
        backgroundColor: context.colors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: context.colors.textMuted,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center_outlined), label: 'Treinos'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), label: 'Nutrição'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
