import 'package:flutter/material.dart';

import '../../../../widgets/coming_soon_tab.dart';
import '../../../../widgets/role_dashboard_scaffold.dart';
import 'distributor_home_tab.dart';
import '../../../../data/models/delivery.dart';
import '../wizards/new_receive_delivery_wizard.dart';

class DistributorDashboardScreen extends StatelessWidget {
  const DistributorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Distributor',
      tabs: [
        RoleDashboardTab(
          label: 'Home',
          icon: Icons.home_rounded,
          body: const DistributorHomeTab(),
          floatingActionButton: Builder(
            builder: (fabContext) => FloatingActionButton.extended(
              onPressed: () async {
                final delivery = await Navigator.of(fabContext)
                    .push<Delivery>(MaterialPageRoute(
                  builder: (_) => const NewReceiveDeliveryWizard(),
                ));
                if (delivery != null && fabContext.mounted) {
                  ScaffoldMessenger.of(fabContext)
                    ..clearSnackBars()
                    ..showSnackBar(SnackBar(
                      content: Text(
                        'Delivery ${delivery.trackingId} created. '
                        'Complete payment to confirm.',
                      ),
                    ));
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New delivery'),
            ),
          ),
        ),
        const RoleDashboardTab(
          label: 'History',
          icon: Icons.receipt_long_rounded,
          body: ComingSoonTab(
            title: 'Delivery history',
            phase: '7',
            icon: Icons.receipt_long_rounded,
          ),
        ),
        const RoleDashboardTab(
          label: 'Rewards',
          icon: Icons.card_giftcard_rounded,
          body: ComingSoonTab(
            title: 'Rewards progress',
            phase: '7',
            icon: Icons.card_giftcard_rounded,
          ),
        ),
        const RoleDashboardTab(
          label: 'Profile',
          icon: Icons.person_rounded,
          body: ComingSoonTab(
            title: 'Profile & settings',
            phase: '7',
            icon: Icons.person_rounded,
          ),
        ),
      ],
    );
  }
}
