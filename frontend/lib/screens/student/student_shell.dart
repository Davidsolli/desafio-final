import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';

class StudentShell extends StatefulWidget {
  final Widget child;

  const StudentShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
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
      backgroundColor: AppColors.background,
      body: widget.child,
      bottomNavigationBar: _buildBottomNav(selectedIndex),
    );
  }

  Widget _buildBottomNav(int selectedIndex) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
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
        backgroundColor: AppColors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center_outlined), label: 'Treinos'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), label: 'Nutrição'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
