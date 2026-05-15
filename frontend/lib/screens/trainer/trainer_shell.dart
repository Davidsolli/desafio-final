import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../models/admin_models.dart';

class TrainerShell extends StatefulWidget {
  final Widget child;

  const TrainerShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends State<TrainerShell> {
  int _getSelectedNavIndex(String currentPath, bool showSheets) {
    if (currentPath.contains('/trainer/home')) return 0;
    if (currentPath.contains('/trainer/students')) return 1;
    if (showSheets && currentPath.contains('/trainer/sheets')) return 2;
    if (currentPath.contains('/trainer/profile')) return showSheets ? 3 : 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final role = context.watch<AuthProvider>().user?.role ?? 'personal_trainer';
    final showSheets = hasRole(role, 'personal_trainer') || role == 'admin';
    final selectedIndex = _getSelectedNavIndex(currentPath, showSheets);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: widget.child,
      bottomNavigationBar: _buildBottomNav(selectedIndex, showSheets),
    );
  }

  Widget _buildBottomNav(int selectedIndex, bool showSheets) {
    final routes = showSheets
        ? ['/trainer/home', '/trainer/students', '/trainer/sheets', '/trainer/profile']
        : ['/trainer/home', '/trainer/students', '/trainer/profile'];

    final items = showSheets
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outlined), label: 'Alunos'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Fichas'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outlined), label: 'Alunos'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
          ];

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => context.go(routes[index]),
        backgroundColor: context.colors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: context.colors.textMuted,
        items: items,
      ),
    );
  }
}
