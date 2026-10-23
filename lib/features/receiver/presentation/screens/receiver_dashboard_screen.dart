import 'package:flutter/material.dart';

import '../../../../widgets/placeholder_dashboard.dart';

class ReceiverDashboardScreen extends StatelessWidget {
  const ReceiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderDashboard(
      title: 'Receiver',
      roleLabel: 'Receiver',
      icon: Icons.inventory_2_rounded,
      phaseHint: 'Receiver dashboard is built in Phase 9.',
    );
  }
}