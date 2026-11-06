import 'package:flutter/material.dart';

import '../../../../widgets/role_dashboard_scaffold.dart';
import 'receiver_history_tab.dart';
import 'receiver_packages_tab.dart';
import 'receiver_profile_tab.dart';
import 'receiver_regional_tab.dart';

class ReceiverDashboardScreen extends StatelessWidget {
  const ReceiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Receiver',
      tabs: const [
        // Packages (Phase 9.2)
        RoleDashboardTab(
          label: 'Packages',
          icon: Icons.inventory_2_rounded,
          body: ReceiverPackagesTab(),
        ),
        // Regional (Phase 9.3)
        RoleDashboardTab(
          label: 'Regional',
          icon: Icons.local_shipping_rounded,
          body: ReceiverRegionalTab(),
        ),
        // History (Phase 9.4)
        RoleDashboardTab(
          label: 'History',
          icon: Icons.history_rounded,
          body: ReceiverHistoryTab(),
        ),
        // Profile (Phase 9.4)
        RoleDashboardTab(
          label: 'Profile',
          icon: Icons.person_rounded,
          body: ReceiverProfileTab(),
        ),
      ],
    );
  }
}