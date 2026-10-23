import 'package:flutter/material.dart';

import '../../../../../widgets/coming_soon_tab.dart';
import '../../../../../widgets/role_dashboard_scaffold.dart';

class ManagerDashboardScreen extends StatelessWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Manager',
      tabs: const [
        RoleDashboardTab(
          label: 'Home',
          icon: Icons.dashboard_rounded,
          body: ComingSoonTab(
            title: 'Manager dashboard',
            phase: '6',
            icon: Icons.dashboard_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Staff',
          icon: Icons.badge_rounded,
          body: ComingSoonTab(
            title: 'Staff management',
            phase: '6',
            icon: Icons.badge_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Deliveries',
          icon: Icons.local_shipping_rounded,
          body: ComingSoonTab(
            title: 'Delivery oversight',
            phase: '6',
            icon: Icons.local_shipping_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Packages',
          icon: Icons.inventory_2_rounded,
          body: ComingSoonTab(
            title: 'Package handling',
            phase: '6',
            icon: Icons.inventory_2_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Profile',
          icon: Icons.person_rounded,
          body: ComingSoonTab(
            title: 'Branch profile',
            phase: '6',
            icon: Icons.person_rounded,
          ),
        ),
      ],
    );
  }
}
