import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/route_names.dart';

/// One tab definition for a [RoleDashboardScaffold].
class RoleDashboardTab {
  final String label;
  final IconData icon;
  final Widget body;

  const RoleDashboardTab({
    required this.label,
    required this.icon,
    required this.body,
  });
}

/// Shared layout used by every role dashboard:
///   - AppBar with role name + a "back to login" escape hatch
///   - Body that switches between tabs via [IndexedStack]
///   - Bottom [NavigationBar] with role-specific destinations
///
/// All five role dashboards use this widget so navigation feel, animation
/// timing, and spacing stay consistent. Future phases replace only the
/// `body` of individual tabs — never the scaffold itself.
class RoleDashboardScaffold extends StatefulWidget {
  final String title;
  final List<RoleDashboardTab> tabs;
  final int initialIndex;

  RoleDashboardScaffold({
    super.key,
    required this.title,
    required this.tabs,
    this.initialIndex = 0,
  }) {
    assert(tabs.length >= 2 && tabs.length <= 5,
        'NavigationBar supports 2–5 destinations.');
  }

  @override
  State<RoleDashboardScaffold> createState() => _RoleDashboardScaffoldState();
}

class _RoleDashboardScaffoldState extends State<RoleDashboardScaffold> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.tabs.length - 1);
  }

  void _onTabSelected(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Back to login',
            icon: const Icon(Icons.logout),
            onPressed: () => context.go(RouteNames.login),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [for (final tab in widget.tabs) tab.body],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabSelected,
        destinations: [
          for (final tab in widget.tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
