import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'product_list_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  const _NavItem(this.label, this.icon, this.selectedIcon, this.page);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isOwner = context.select<AuthProvider, bool>((a) => a.isOwner);

    final items = <_NavItem>[
      const _NavItem(
          'Home', Icons.dashboard_outlined, Icons.dashboard, DashboardScreen()),
      const _NavItem('Stock', Icons.inventory_2_outlined, Icons.inventory_2,
          ProductListScreen()),
      const _NavItem(
          'History', Icons.history, Icons.history_toggle_off, HistoryScreen()),
      if (isOwner)
        const _NavItem(
            'Reports', Icons.insights_outlined, Icons.insights, ReportsScreen()),
      const _NavItem(
          'Profile', Icons.person_outline, Icons.person, ProfileScreen()),
    ];
    final index = _index >= items.length ? 0 : _index;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [for (final i in items) i.page],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final i in items)
            NavigationDestination(
              icon: Icon(i.icon),
              selectedIcon: Icon(i.selectedIcon),
              label: i.label,
            ),
        ],
      ),
    );
  }
}