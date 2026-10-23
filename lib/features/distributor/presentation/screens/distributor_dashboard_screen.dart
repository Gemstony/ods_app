import 'package:flutter/material.dart';

import '../../../../../widgets/coming_soon_tab.dart';
import '../../../../../widgets/role_dashboard_scaffold.dart';

class DistributorDashboardScreen extends StatelessWidget {
  const DistributorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Distributor',
      tabs: const [
        RoleDashboardTab(
          label: 'Home',
          icon: Icons.home_rounded,
          body: ComingSoonTab(
            title: 'Distributor dashboard',
            phase: '7',
            icon: Icons.home_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'New',
          icon: Icons.add_circle_outline_rounded,
          body: ComingSoonTab(
            title: 'Create delivery request',
            phase: '7',
            icon: Icons.add_circle_outline_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'History',
          icon: Icons.receipt_long_rounded,
          body: ComingSoonTab(
            title: 'Delivery history',
            phase: '7',
            icon: Icons.receipt_long_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Rewards',
          icon: Icons.card_giftcard_rounded,
          body: ComingSoonTab(
            title: 'Rewards progress',
            phase: '13',
            icon: Icons.card_giftcard_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Profile',
          icon: Icons.person_rounded,
          body: ComingSoonTab(
            title: 'Profile & settings',
            phase: '7',
            icon: Icons.person_rounded,
          ),
        ),
      ],
    );
  }
}
