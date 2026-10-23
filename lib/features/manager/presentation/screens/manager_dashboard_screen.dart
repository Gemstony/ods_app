import 'package:flutter/material.dart';

import '../../../../widgets/placeholder_dashboard.dart';

class ManagerDashboardScreen extends StatelessWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDashboard(
      title: 'Manager',
      roleLabel: 'Manager',
      icon: Icons.storefront_rounded,
      phaseHint: 'Manager dashboard is built in Phase 6.',
    );
  }
}