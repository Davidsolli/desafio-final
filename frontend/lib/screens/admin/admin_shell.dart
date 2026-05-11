import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

class AdminShell extends StatefulWidget {
  final Widget child;

  const AdminShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _getSelectedNavIndex(String currentPath) {
    if (currentPath.contains('/admin/trainers')) return 0;
    if (currentPath.contains('/admin/whatsapp')) return 1;
    if (currentPath.contains('/admin/settings')) return 2;
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
            '/admin/trainers',
            '/admin/whatsapp',
            '/admin/settings',
          ];
          context.go(routes[index]);
        },
        backgroundColor: context.colors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: context.colors.textMuted,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people_outlined), label: 'Trainers'),
          BottomNavigationBarItem(icon: Icon(Icons.mark_chat_unread_outlined), label: 'WhatsApp'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Configurações'),
        ],
      ),
    );
  }
}
