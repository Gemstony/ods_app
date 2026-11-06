import 'package:flutter/material.dart';

import '../../../../widgets/coming_soon_tab.dart';
import '../../../../widgets/role_dashboard_scaffold.dart';
import 'receiver_packages_tab.dart';
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
          body: ComingSoonTab(
            title: 'Handover history',
            phase: '9.4',
            icon: Icons.history_rounded,
          ),
        ),
        // Profile (Phase 9.4)
        RoleDashboardTab(
          label: 'Profile',
          icon: Icons.person_rounded,
          body: ComingSoonTab(
            title: 'Receiver profile',
            phase: '9.4',
            icon: Icons.person_rounded,
          ),
        ),
      ],
    );
  }
}