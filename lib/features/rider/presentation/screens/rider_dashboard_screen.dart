import 'package:flutter/material.dart';

import '../../../../../widgets/coming_soon_tab.dart';
import '../../../../../widgets/role_dashboard_scaffold.dart';

class RiderDashboardScreen extends StatelessWidget {
  const RiderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Delivery Agent',
      tabs: const [
        RoleDashboardTab(
          label: 'Tasks',
          icon: Icons.assignment_rounded,
          body: ComingSoonTab(
            title: 'Available tasks',
            phase: '8',
            icon: Icons.assignment_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Active',
          icon: Icons.delivery_dining_rounded,
          body: ComingSoonTab(
            title: 'Active delivery',
            phase: '8',
            icon: Icons.delivery_dining_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Earnings',
          icon: Icons.payments_rounded,
          body: ComingSoonTab(
            title: 'Earnings & payouts',
            phase: '11',
            icon: Icons.payments_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Profile',
          icon: Icons.person_rounded,
          body: ComingSoonTab(
            title: 'Rider profile',
            phase: '8',
            icon: Icons.person_rounded,
          ),
        ),
      ],
    );
  }
}
