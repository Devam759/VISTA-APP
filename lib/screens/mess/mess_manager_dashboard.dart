import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/mess/mess_feedback_analytics_view.dart';
import '../../widgets/mess/mess_scanner_tab.dart';
import '../../widgets/mess/mess_weekly_editor_tab.dart';
import '../../widgets/mess/mess_scan_logs_tab.dart';
import '../../widgets/common/web_dashboard_scaffold.dart';

class MessManagerDashboard extends StatefulWidget {
  const MessManagerDashboard({super.key});

  @override
  State<MessManagerDashboard> createState() => _MessManagerDashboardState();
}

class _MessManagerDashboardState extends State<MessManagerDashboard> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userProfile;

    final pages = [
      MessScannerTab(isActive: _currentTab == 0),
      const MessWeeklyEditorTab(),
      const MessScanLogsTab(),
      const MessFeedbackAnalyticsView(),
    ];

    const items = [
      WebNavigationItem(
        icon: Icons.qr_code_scanner_rounded,
        selectedIcon: Icons.qr_code_scanner_rounded,
        label: 'Scanner',
      ),
      WebNavigationItem(
        icon: Icons.restaurant_menu_rounded,
        selectedIcon: Icons.restaurant_menu_rounded,
        label: 'Weekly Menu',
      ),
      WebNavigationItem(
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check_rounded,
        label: 'Scan Logs',
      ),
      WebNavigationItem(
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics_rounded,
        label: 'Feedback',
      ),
    ];

    return WebDashboardScaffold(
      title: 'VISTA',
      roleBadge: 'MESS MANAGER',
      userName: user?.name ?? 'Mess Manager',
      items: items,
      selectedIndex: _currentTab,
      onItemSelected: (index) => setState(() => _currentTab = index),
      onSignOut: () => authProvider.signOut(),
      pages: pages,
    );
  }
}
