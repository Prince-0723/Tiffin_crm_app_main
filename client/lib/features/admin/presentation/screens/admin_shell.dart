import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import 'admin_dashboard_screen.dart';
import 'admin_list_screen.dart';
import 'admin_reports_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedTab = 0;

  void _onListTap(AdminListType type) {
    switch (type) {
      case AdminListType.vendors:
        setState(() => _selectedTab = 1);
        break;
      case AdminListType.customers:
        setState(() => _selectedTab = 2);
        break;
      case AdminListType.orders:
        setState(() => _selectedTab = 3);
        break;
      default:
        context.push(AppRoutes.adminList, extra: type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          RepaintBoundary(
            child: AdminDashboardScreen(
              onListTap: _onListTap,
              onReportsTap: () => setState(() => _selectedTab = 4),
            ),
          ),
          const RepaintBoundary(
            child: AdminListScreen(type: AdminListType.vendors),
          ),
          const RepaintBoundary(
            child: AdminListScreen(type: AdminListType.customers),
          ),
          const RepaintBoundary(
            child: AdminListScreen(type: AdminListType.orders),
          ),
          const RepaintBoundary(
            child: AdminReportsScreen(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Vendors'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Customers'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Reports'),
        ],
      ),
    );
  }
}
