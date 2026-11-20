import 'package:flutter/material.dart';

import '../../../../widgets/coming_soon_tab.dart';
import '../../../../widgets/role_dashboard_scaffold.dart';
import 'branch_form_screen.dart';
import 'owner_branches_tab.dart';
import 'owner_home_tab.dart';
import 'owner_users_tab.dart';
import 'owner_settings_tab.dart';
import 'owner_finance_tab.dart';
import 'user_form_screen.dart';

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
          floatingActionButton: _AddUserFab(),
        ),
        const RoleDashboardTab(
          label: 'Finance',
          icon: Icons.account_balance_wallet_rounded,
          body: OwnerFinanceTab(),
        ),
        const RoleDashboardTab(
          label: 'Settings',
          icon: Icons.settings_rounded,
          body: OwnerSettingsTab(),
        ),
      ],
    );
  }
}

class _AddUserFab extends StatelessWidget {
  const _AddUserFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UserFormScreen()),
      ),
      tooltip: 'Add user',
      child: const Icon(Icons.add),
    );
  }
}
