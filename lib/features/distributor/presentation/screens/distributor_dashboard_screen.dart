import 'package:flutter/material.dart';

import '../../../../data/models/delivery.dart';
import '../../../../widgets/role_dashboard_scaffold.dart';
import '../wizards/new_receive_delivery_wizard.dart';
import '../wizards/new_regional_delivery_wizard.dart';
import '../wizards/new_send_delivery_wizard.dart';
import '../wizards/widgets/service_picker_sheet.dart';
import 'distributor_history_tab.dart';
import 'distributor_home_tab.dart';
import 'distributor_profile_tab.dart';
import 'distributor_rewards_tab.dart';

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
                // Ask which service the distributor wants.
                final choice = await ServicePickerSheet.show(fabContext);
                if (choice == null || !fabContext.mounted) return;

                // Route to the correct wizard. Switch is exhaustive over
                // DeliveryServiceChoice (3 values), so `wizard` is
                // non-nullable — no `!` needed.
                final Widget wizard = switch (choice) {
                  DeliveryServiceChoice.receive =>
                    const NewReceiveDeliveryWizard(),
                  DeliveryServiceChoice.send =>
                    const NewSendDeliveryWizard(),
                  DeliveryServiceChoice.regional =>
                    const NewRegionalDeliveryWizard(),
                };

                final delivery = await Navigator.of(fabContext).push<Delivery>(
                  MaterialPageRoute(builder: (_) => wizard),
                );
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
          body: DistributorHistoryTab(),
        ),
        const RoleDashboardTab(
          label: 'Rewards',
          icon: Icons.card_giftcard_rounded,
          body: DistributorRewardsTab(),
        ),
        const RoleDashboardTab(
          label: 'Profile',
          icon: Icons.person_rounded,
          body: DistributorProfileTab(),
        ),
      ],
    );
  }
}