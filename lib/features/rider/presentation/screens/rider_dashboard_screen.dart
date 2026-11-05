import 'package:flutter/material.dart';

import '../../../../widgets/coming_soon_tab.dart';
import '../../../../widgets/role_dashboard_scaffold.dart';
import 'rider_home_tab.dart';
import 'rider_tasks_tab.dart';

class RiderDashboardScreen extends StatelessWidget {
  const RiderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Delivery Agent',
      tabs: const [
        // Home (Phase 8.2) — KPI overview + active task + recent
        RoleDashboardTab(
          label: 'Home',
          icon: Icons.home_rounded,
          body: RiderHomeTab(),
        ),
        // Tasks (Phase 8.3) — full list + accept flow
        RoleDashboardTab(
          label: 'Tasks',
          icon: Icons.assignment_rounded,
          body: RiderTasksTab(),
        ),
        // Active (Phase 8.4) — pickup + deliver with code entry
        RoleDashboardTab(
          label: 'Active',
          icon: Icons.delivery_dining_rounded,
          body: ComingSoonTab(
            title: 'Active delivery',
            phase: '8.4',
            icon: Icons.delivery_dining_rounded,
          ),
        ),
        // Earnings (Phase 8.5)
        RoleDashboardTab(
          label: 'Earnings',
          icon: Icons.payments_rounded,
          body: ComingSoonTab(
            title: 'Earnings & payouts',
            phase: '8.5',
            icon: Icons.payments_rounded,
          ),
        ),
        // Profile (Phase 8.6)
        RoleDashboardTab(
          label: 'Profile',
          icon: Icons.person_rounded,
          body: ComingSoonTab(
            title: 'Rider profile',
            phase: '8.6',
            icon: Icons.person_rounded,
          ),
        ),
      ],
    );
  }
}