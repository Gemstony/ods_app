import 'package:flutter/material.dart';

import '../../../../widgets/coming_soon_tab.dart';
import '../../../../widgets/role_dashboard_scaffold.dart';
import 'manager_home_tab.dart';
import 'manager_staff_tab.dart';
import 'manager_deliveries_tab.dart';
import 'manager_packages_tab.dart';

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
          body: ManagerHomeTab(),
        ),
        RoleDashboardTab(
          label: 'Staff',
          icon: Icons.badge_rounded,
          body: const ManagerStaffTab(),
        ),
        RoleDashboardTab(
          label: 'Deliveries',
          icon: Icons.local_shipping_rounded,
          body: const ManagerDeliveriesTab(),
        ),
        RoleDashboardTab(
          label: 'Packages',
          icon: Icons.inventory_2_rounded,
          body: const ManagerPackagesTab(),
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
