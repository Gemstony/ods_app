import 'package:flutter/material.dart';

import '../../../../widgets/coming_soon_tab.dart';
import '../../../../widgets/role_dashboard_scaffold.dart';
import 'branch_form_screen.dart';
import 'owner_branches_tab.dart';
import 'owner_home_tab.dart';
import 'owner_users_tab.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Owner',
      tabs: [
        const RoleDashboardTab(
          label: 'Home',
          icon: Icons.dashboard_rounded,
          body: OwnerHomeTab(),
        ),
        RoleDashboardTab(
          label: 'Branches',
          icon: Icons.store_rounded,
          body: const OwnerBranchesTab(),
          floatingActionButton: Builder(
            builder: (fabContext) => FloatingActionButton(
              onPressed: () => Navigator.of(fabContext).push(
                MaterialPageRoute(
                  builder: (_) => const BranchFormScreen(),
                ),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ),
        const RoleDashboardTab(
          label: 'Users',
          icon: Icons.people_rounded,
          body: OwnerUsersTab(),
        ),
        const RoleDashboardTab(
          label: 'Finance',
          icon: Icons.account_balance_wallet_rounded,
          body: ComingSoonTab(
            title: 'Financial oversight',
            phase: '11',
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
        const RoleDashboardTab(
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