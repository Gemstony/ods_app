import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';
import '../providers/rider_active_providers.dart';
import '../providers/rider_dashboard_providers.dart';
import '../providers/rider_tasks_providers.dart';

/// The Rider's Active tab — deliveries currently in-hand.
///
/// Two lifecycle states are shown:
///   - `accepted`  → CTA "Pickup package"   (pickup from branch)
///   - `picked_up` → CTA "Confirm delivery" (handover to recipient)
///
/// Both actions follow the same flow: confirm dialog → per-tile spinner
/// → API call → refresh + snackbar. After pickup, the card updates to
/// "picked_up" in place; after deliver, it drops out of the list.
///
/// Deliver has no verification code yet — Phase 12 adds code entry
/// (DISTRIBUTOR_CODE / RECIPIENT_CODE). The backend's `deliver` endpoint
/// (Phase 8.1) is currently a plain status transition.
class RiderActiveTab extends ConsumerStatefulWidget {
  const RiderActiveTab({super.key});

  @override
  ConsumerState<RiderActiveTab> createState() => _RiderActiveTabState();
}

class _RiderActiveTabState extends ConsumerState<RiderActiveTab> {
  /// Delivery IDs with an in-flight pickup/deliver request — renders
  /// a spinner on those tiles only, keeping the rest interactive.
  final Set<int> _busyIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(riderTasksProvider);

    return tasksAsync.when(
      loading: () => const LoadingView(message: 'Loading active deliveries…'),
      error: (_, __) => ErrorView(
        message: 'Could not load active deliveries.',
        onRetry: () => ref.invalidate(riderTasksProvider),
      ),
      data: (_) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final active = ref.watch(riderActiveDeliveriesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(riderTasksProvider);
        await ref.read(riderTasksProvider.future);
      },
      child: active.isEmpty
          ? _buildEmptyScrollable()
          : _buildList(active),
    );
  }

  Widget _buildList(List<Delivery> active) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: active.length,
      itemBuilder: (context, i) {
        final delivery = active[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _ActiveDeliveryCard(
            delivery: delivery,
            isBusy: _busyIds.contains(delivery.id),
            onPickup: () => _onPickupTap(delivery),
            onDeliver: () => _onDeliverTap(delivery),
          ),
        );
      },
    );
  }

  Widget _buildEmptyScrollable() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: const [
        SizedBox(height: 80),
        _EmptyState(),
      ],
    );
  }

  // ─── Pickup flow ────────────────────────────────────────
  Future<void> _onPickupTap(Delivery delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pickup package?'),
        content: Text(
          'Confirm you have collected ${delivery.trackingId} from the '
          'branch. Only tap Pickup once the package is physically in '
          'your hands.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Pickup'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyIds.add(delivery.id));

    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.pickupRiderDelivery(delivery.id);

    if (!mounted) return;
    setState(() => _busyIds.remove(delivery.id));

    result.fold(
      onSuccess: (_) {
        ref.invalidate(riderTasksProvider);
        ref.invalidate(riderHomeProvider);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text(
              'Package picked up. Confirm delivery when you hand it over.',
            ),
          ));
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  // ─── Deliver flow ───────────────────────────────────────
  Future<void> _onDeliverTap(Delivery delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm delivery?'),
        content: Text(
          'Confirm that ${delivery.trackingId} has been handed over to '
          'the recipient. This completes the delivery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyIds.add(delivery.id));

    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.deliverRiderDelivery(delivery.id);

    if (!mounted) return;
    setState(() => _busyIds.remove(delivery.id));

    result.fold(
      onSuccess: (_) {
        ref.invalidate(riderTasksProvider);
        ref.invalidate(riderHomeProvider);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Delivery completed. Nice work!'),
          ));
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Active delivery card — focus-mode layout
// ─────────────────────────────────────────────────────────────

class _ActiveDeliveryCard extends StatelessWidget {
  final Delivery delivery;
  final bool isBusy;
  final VoidCallback onPickup;
  final VoidCallback onDeliver;

  const _ActiveDeliveryCard({
    required this.delivery,
    required this.isBusy,
    required this.onPickup,
    required this.onDeliver,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header: tracking + status ─────────────────
          Row(
            children: [
              const Icon(
                Icons.delivery_dining_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  delivery.trackingId,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DeliveryStatusChip(status: delivery.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ─── Addresses ─────────────────────────────────
          if (delivery.pickupAddress != null)
            _AddressRow(
              icon: Icons.warehouse_outlined,
              label: 'Pickup',
              value: delivery.pickupAddress!,
            ),
          if (_destinationLabel() != null) ...[
            if (delivery.pickupAddress != null)
              const SizedBox(height: AppSpacing.xxs),
            _AddressRow(
              icon: Icons.place_outlined,
              label: 'Drop at',
              value: _destinationLabel()!,
            ),
          ],

          // ─── Recipient ─────────────────────────────────
          if (delivery.recipientName != null ||
              delivery.recipientPhone != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (delivery.recipientName != null)
                          Text(
                            delivery.recipientName!,
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (delivery.recipientPhone != null)
                          Text(
                            delivery.recipientPhone!,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.onSurfaceMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // ─── Primary CTA ───────────────────────────────
          _PrimaryCta(
            status: delivery.status,
            isBusy: isBusy,
            onPickup: onPickup,
            onDeliver: onDeliver,
          ),
        ],
      ),
    );
  }

  String? _destinationLabel() {
    if (delivery.isRegional) {
      final parts = <String>[];
      if (delivery.destinationRegion != null) parts.add(delivery.destinationRegion!);
      if (delivery.destinationDistrict != null) parts.add(delivery.destinationDistrict!);
      if (parts.isNotEmpty) return parts.join(' · ');
      return 'Regional destination';
    }
    return delivery.destinationAddress;
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AddressRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.onSurfaceMuted),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  final DeliveryStatus status;
  final bool isBusy;
  final VoidCallback onPickup;
  final VoidCallback onDeliver;

  const _PrimaryCta({
    required this.status,
    required this.isBusy,
    required this.onPickup,
    required this.onDeliver,
  });

  @override
  Widget build(BuildContext context) {
    final (label, icon, onTap) = status == DeliveryStatus.accepted
        ? ('Pickup package', Icons.inventory_2_rounded, onPickup)
        : ('Confirm delivery', Icons.check_circle_rounded, onDeliver);

    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: isBusy ? null : onTap,
        icon: isBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(
          isBusy ? 'Please wait…' : label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.surface,
          child: Icon(
            Icons.delivery_dining_outlined,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No active deliveries',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Accept a task from the Tasks tab to see it here.',
          style: text.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}