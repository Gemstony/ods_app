import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';
import '../../../shared/presentation/widgets/verification_code_entry_sheet.dart';
import '../providers/rider_active_providers.dart';
import '../providers/rider_dashboard_providers.dart';
import '../providers/rider_tasks_providers.dart';

class RiderActiveTab extends ConsumerStatefulWidget {
  const RiderActiveTab({super.key});

  @override
  ConsumerState<RiderActiveTab> createState() => _RiderActiveTabState();
}

class _RiderActiveTabState extends ConsumerState<RiderActiveTab> {
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
      child: active.isEmpty ? _buildEmptyScrollable() : _buildList(active),
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

    if (_handleIfVerificationRequired(
      result: result,
      delivery: delivery,
      codeType: 'distributor',
      actionLabel: 'pickup',
      submitWithCode: (code) =>
          repo.pickupRiderDelivery(delivery.id, verificationCode: code),
      onSuccess: _handlePickupSuccess,
    )) {
      return;
    }

    result.fold(
      onSuccess: (_) => _handlePickupSuccess(),
      onFailure: (f) => _showSnackbar(f.message),
    );
  }

  void _handlePickupSuccess() {
    ref.invalidate(riderTasksProvider);
    ref.invalidate(riderHomeProvider);
    _showSnackbar(
      'Package picked up. Confirm delivery when you hand it over.',
    );
  }

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

    if (_handleIfVerificationRequired(
      result: result,
      delivery: delivery,
      codeType: 'recipient',
      actionLabel: 'deliver',
      submitWithCode: (code) =>
          repo.deliverRiderDelivery(delivery.id, verificationCode: code),
      onSuccess: _handleDeliverSuccess,
    )) {
      return;
    }

    result.fold(
      onSuccess: (_) => _handleDeliverSuccess(),
      onFailure: (f) => _showSnackbar(f.message),
    );
  }

  void _handleDeliverSuccess() {
    ref.invalidate(riderTasksProvider);
    ref.invalidate(riderHomeProvider);
    _showSnackbar('Delivery completed. Nice work!');
  }

   bool _handleIfVerificationRequired({
    required ApiResult<Delivery> result,
    required Delivery delivery,
    required String codeType,
    required String actionLabel,
    required Future<ApiResult<Delivery>> Function(String code) submitWithCode,
    required VoidCallback onSuccess,
  }) {
    bool verificationRequired = false;

    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) {
        verificationRequired = failure.message
            .toLowerCase()
            .contains('verification code is required');
      },
    );

    if (!verificationRequired) return false;

    VerificationCodeEntrySheet.show(
      context,
      delivery: delivery,
      codeType: codeType,
      actionLabel: actionLabel,
      onSubmit: submitWithCode,
    ).then((updated) {
      if (updated != null) onSuccess();
    });
    return true;
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ─────────────────────────────────────────────────────────────
// Active delivery card
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
      if (delivery.destinationRegion != null) {
        parts.add(delivery.destinationRegion!);
      }
      if (delivery.destinationDistrict != null) {
        parts.add(delivery.destinationDistrict!);
      }
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