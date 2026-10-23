import 'package:flutter/material.dart';

import '../../../../../widgets/coming_soon_tab.dart';
import '../../../../../widgets/role_dashboard_scaffold.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Owner',
      tabs: const [
        RoleDashboardTab(
          label: 'Home',
          icon: Icons.dashboard_rounded,
          body: ComingSoonTab(
            title: 'Owner dashboard',
            phase: '5',
            icon: Icons.dashboard_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Branches',
          icon: Icons.store_rounded,
          body: ComingSoonTab(
            title: 'Branch management',
            phase: '5',
            icon: Icons.store_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Users',
          icon: Icons.people_rounded,
          body: ComingSoonTab(
            title: 'User management',
            phase: '5',
            icon: Icons.people_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Finance',
          icon: Icons.account_balance_wallet_rounded,
          body: ComingSoonTab(
            title: 'Financial oversight',
            phase: '11',
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
        RoleDashboardTab(
          label: 'Settings',
          icon: Icons.settings_rounded,
          body: ComingSoonTab(
            title: 'Configuration',
            phase: '5',
            icon: Icons.settings_rounded,
          ),
        ),
      ],
    );
  }
}
