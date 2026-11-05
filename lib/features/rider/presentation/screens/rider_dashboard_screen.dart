import 'package:flutter/material.dart';

import '../../../../widgets/role_dashboard_scaffold.dart';
import 'rider_active_tab.dart';
import 'rider_earnings_tab.dart';
import 'rider_home_tab.dart';
import 'rider_profile_tab.dart';
import 'rider_tasks_tab.dart';

class RiderDashboardScreen extends StatelessWidget {
  const RiderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Delivery Agent',
      tabs: const [
        // Home (8.2)
        RoleDashboardTab(
          label: 'Home',
          icon: Icons.home_rounded,
          body: RiderHomeTab(),
        ),
        // Tasks (8.3)
        RoleDashboardTab(
          label: 'Tasks',
          icon: Icons.assignment_rounded,
          body: RiderTasksTab(),
        ),
        // Active (8.4)
        RoleDashboardTab(
          label: 'Active',
          icon: Icons.delivery_dining_rounded,
          body: RiderActiveTab(),
        ),
        // Earnings (8.5)
        RoleDashboardTab(
          label: 'Earnings',
          icon: Icons.payments_rounded,
          body: RiderEarningsTab(),
        ),
        // Profile (8.6)
        RoleDashboardTab(
          label: 'Profile',
          icon: Icons.person_rounded,
          body: RiderProfileTab(),
        ),
      ],
    );
  }
}