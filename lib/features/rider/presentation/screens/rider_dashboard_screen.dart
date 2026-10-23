import 'package:flutter/material.dart';

import '../../../../widgets/placeholder_dashboard.dart';

class RiderDashboardScreen extends StatelessWidget {
  const RiderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDashboard(
      title: 'Delivery Agent',
      roleLabel: 'Delivery Agent',
      icon: Icons.delivery_dining_rounded,
      phaseHint: 'Delivery Agent dashboard is built in Phase 8.',
    );
  }
}