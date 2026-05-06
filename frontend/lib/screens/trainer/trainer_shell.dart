import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

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
  int _getSelectedNavIndex(String currentPath) {
    // if (currentPath.contains('/trainer/home')) return 0;
    if (currentPath.contains('/trainer/students')) return 0;
    if (currentPath.contains('/trainer/sheets')) return 1;
    if (currentPath.contains('/trainer/profile')) return 2;
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
            // '/trainer/home', // Removido temporariamente para apresentação
            '/trainer/students',
            '/trainer/sheets',
            '/trainer/profile',
          ];
          context.go(routes[index]);
        },
        backgroundColor: context.colors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: context.colors.textMuted,
        items: const [
          // BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'), // Removido temporariamente
          BottomNavigationBarItem(icon: Icon(Icons.people_outlined), label: 'Alunos'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Fichas'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
