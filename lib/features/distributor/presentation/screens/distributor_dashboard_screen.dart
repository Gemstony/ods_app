import 'package:flutter/material.dart';

import '../../../../widgets/placeholder_dashboard.dart';

class DistributorDashboardScreen extends StatelessWidget {
  const DistributorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDashboard(
      title: 'Distributor',
      roleLabel: 'Distributor',
      icon: Icons.shopping_bag_rounded,
      phaseHint: 'Distributor dashboard is built in Phase 7.',
    );
  }
}