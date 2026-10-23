import 'package:flutter/material.dart';

import '../../../../widgets/placeholder_dashboard.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDashboard(
      title: 'Owner',
      roleLabel: 'Owner',
      icon: Icons.admin_panel_settings_rounded,
      phaseHint: 'Owner dashboard is built in Phase 5.',
    );
  }
}