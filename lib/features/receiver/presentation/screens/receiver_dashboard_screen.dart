import 'package:flutter/material.dart';

import '../../../../../widgets/coming_soon_tab.dart';
import '../../../../../widgets/role_dashboard_scaffold.dart';

class ReceiverDashboardScreen extends StatelessWidget {
  const ReceiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Receiver',
      tabs: const [
        RoleDashboardTab(
          label: 'Packages',
          icon: Icons.inventory_2_rounded,
          body: ComingSoonTab(
            title: 'Package verification',
            phase: '9',
            icon: Icons.inventory_2_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Regional',
          icon: Icons.map_rounded,
          body: ComingSoonTab(
            title: 'Regional dispatch',
            phase: '9',
            icon: Icons.map_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'History',
          icon: Icons.history_rounded,
          body: ComingSoonTab(
            title: 'Package history',
            phase: '9',
            icon: Icons.history_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Profile',
          icon: Icons.person_rounded,
          body: ComingSoonTab(
            title: 'Receiver profile',
            phase: '9',
            icon: Icons.person_rounded,
          ),
        ),
      ],
    );
  }
}
