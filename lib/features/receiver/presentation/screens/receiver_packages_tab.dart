import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../data/models/package_verify_result.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';
import '../providers/receiver_packages_providers.dart';

/// The Receiver's Packages tab — receive-service deliveries at the
/// receiver's branch, with the handover (verify → release) flow.
///
/// Release button appears only on `accepted` deliveries (rider has
/// accepted, awaiting branch handover). The flow:
///   1. Tap Release → verify endpoint (catches stale state after list load)
///   2. If can_release: confirm dialog showing rider name → release
///   3. If not: informational dialog showing reason
///
/// Busy state is scoped to the two API calls (verify, release) only —
/// never overlaps with a dialog, so `pumpAndSettle` and the user-facing
/// flow both stay responsive.
///
/// Phase 12 will layer code verification onto the same verify → release
/// flow without changing this UI structure.
class ReceiverPackagesTab extends ConsumerStatefulWidget {
  const ReceiverPackagesTab({super.key});

  @override
  ConsumerState<ReceiverPackagesTab> createState() =>
      _ReceiverPackagesTabState();
}

class _ReceiverPackagesTabState extends ConsumerState<ReceiverPackagesTab> {
  /// Delivery IDs with an in-flight verify/release request. Renders a
  /// spinner on those tiles only, keeping the rest interactive.
  final Set<int> _busyIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(receiverPackagesProvider);

    return async.when(
      loading: () => const LoadingView(message: 'Loading packages…'),
      error: (_, __) => ErrorView(
        message: 'Could not load packages.',
        onRetry: () => ref.invalidate(receiverPackagesProvider),
      ),
      data: (_) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final filter = ref.watch(receiverPackagesFilterProvider);
    final filtered = ref.watch(filteredReceiverPackagesProvider);
    final hasAny =
        (ref.watch(receiverPackagesProvider).valueOrNull ?? const [])
            .isNotEmpty;

    return Column(
      children: [
        _FilterBar(
          filter: filter,
          onChanged: (s) =>
              ref.read(receiverPackagesFilterProvider.notifier).setStatus(s),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(receiverPackagesProvider);
              await ref.read(receiverPackagesProvider.future);
            },
            child: filtered.isEmpty
                ? _buildEmptyScrollable(hasAny: hasAny, filter: filter)
                : _buildList(filtered),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Delivery> packages) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: packages.length,
      itemBuilder: (context, i) {
        final delivery = packages[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _ReceiverPackageCard(
            delivery: delivery,
            isBusy: _busyIds.contains(delivery.id),
            onRelease: () => _onReleaseTap(delivery),
          ),
        );
      },
    );
  }

  Widget _buildEmptyScrollable({
    required bool hasAny,
    required ReceiverPackagesFilter filter,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        const SizedBox(height: 80),
        hasAny
            ? _FilterEmptyState(
                onClear: () =>
                    ref.read(receiverPackagesFilterProvider.notifier).clear(),
              )
            : const _NoPackagesState(),
      ],
    );
  }

  // ─── Release flow ─────────────────────────────────────────
  Future<void> _onReleaseTap(Delivery delivery) async {
    final repo = ref.read(deliveryRepositoryProvider);

    // 1. Verify — busy is on ONLY during this call.
    setState(() => _busyIds.add(delivery.id));
    final verifyResult = await repo.verifyReceiverPackage(delivery.id);
    if (!mounted) return;
    setState(() => _busyIds.remove(delivery.id));

    PackageVerifyResult? verify;
    String? verifyError;
    verifyResult.fold(
      onSuccess: (v) => verify = v,
      onFailure: (f) => verifyError = f.message,
    );

    if (verifyError != null) {
      _showSnackbar(verifyError!);
      return;
    }
    if (verify == null) return;

    // 2. Not ready → informational dialog, no state change.
    //    Busy is already off here — no spinner behind the dialog.
    if (!verify!.canRelease) {
      await _showCannotRelease(
        verify!.reason ?? 'Package cannot be released.',
      );
      return;
    }

    // 3. Ready → confirm dialog (no spinner behind it).
    final riderName = verify!.rider?.name ?? 'the assigned rider';
    final confirmed = await _showConfirm(riderName);
    if (confirmed != true || !mounted) return;

    // 4. Release — busy is on ONLY during this call.
    setState(() => _busyIds.add(delivery.id));
    final releaseResult = await repo.releaseReceiverPackage(delivery.id);
    if (!mounted) return;
    setState(() => _busyIds.remove(delivery.id));

    releaseResult.fold(
      onSuccess: (_) {
        ref.invalidate(receiverPackagesProvider);
        _showSnackbar('Package released.');
      },
      onFailure: (f) => _showSnackbar(f.message),
    );
  }

  Future<bool?> _showConfirm(String riderName) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Release package?'),
        content: Text('Release this package to $riderName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Release'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCannotRelease(String reason) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cannot release'),
        content: Text(reason),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ─────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final ReceiverPackagesFilter filter;
  final ValueChanged<DeliveryStatus?> onChanged;

  const _FilterBar({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('All', null),
            const SizedBox(width: 6),
            _chip('Paid', DeliveryStatus.paid),
            const SizedBox(width: 6),
            _chip('Batched', DeliveryStatus.batched),
            const SizedBox(width: 6),
            _chip('Assigned', DeliveryStatus.assigned),
            const SizedBox(width: 6),
            _chip('Accepted', DeliveryStatus.accepted),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, DeliveryStatus? status) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: filter.status == status,
      onSelected: (_) => onChanged(status),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Package card
// ─────────────────────────────────────────────────────────────

class _ReceiverPackageCard extends StatelessWidget {
  final Delivery delivery;
  final bool isBusy;
  final VoidCallback onRelease;

  const _ReceiverPackageCard({
    required this.delivery,
    required this.isBusy,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canRelease = delivery.status == DeliveryStatus.accepted;
    final helperText = _helperTextFor(delivery.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: canRelease ? AppColors.primary : AppColors.border,
          width: canRelease ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header ─────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.inventory_2_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  delivery.trackingId,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DeliveryStatusChip(status: delivery.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ─── Destination ────────────────────────────────
          if (delivery.destinationAddress != null)
            _InfoRow(
              icon: Icons.place_outlined,
              value: delivery.destinationAddress!,
            ),

          // ─── Recipient ──────────────────────────────────
          if (delivery.recipientName != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            _InfoRow(
              icon: Icons.person_outline_rounded,
              value: delivery.recipientName!,
            ),
          ],

          // ─── Helper hint ────────────────────────────────
          if (helperText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    _hintIconFor(delivery.status),
                    size: 14,
                    color: AppColors.onSurfaceMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      helperText,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ─── Primary CTA ────────────────────────────────
          if (canRelease) ...[
            const SizedBox(height: AppSpacing.md),
            _ReleaseButton(isBusy: isBusy, onPressed: onRelease),
          ],
        ],
      ),
    );
  }

  static String? _helperTextFor(DeliveryStatus status) => switch (status) {
        DeliveryStatus.paid => 'Awaiting rider assignment.',
        DeliveryStatus.batched => 'Batched — awaiting rider assignment.',
        DeliveryStatus.assigned => 'Rider notified, awaiting acceptance.',
        _ => null,
      };

  static IconData _hintIconFor(DeliveryStatus status) => switch (status) {
        DeliveryStatus.paid => Icons.schedule_rounded,
        DeliveryStatus.batched => Icons.hourglass_empty_rounded,
        DeliveryStatus.assigned => Icons.info_outline_rounded,
        _ => Icons.info_outline_rounded,
      };
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.onSurfaceMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            value,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ReleaseButton extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onPressed;

  const _ReleaseButton({required this.isBusy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: isBusy ? null : onPressed,
        icon: isBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.outbox_rounded, size: 18),
        label: Text(
          isBusy ? 'Please wait…' : 'Release to rider',
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
// Empty states
// ─────────────────────────────────────────────────────────────

class _NoPackagesState extends StatelessWidget {
  const _NoPackagesState();

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
            Icons.inventory_2_outlined,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No packages at your branch',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Packages will appear here when they arrive at your branch.',
          style: text.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FilterEmptyState extends StatelessWidget {
  final VoidCallback onClear;
  const _FilterEmptyState({required this.onClear});

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
            Icons.filter_alt_off_rounded,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No packages match your filter',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear_rounded, size: 18),
          label: const Text('Clear filter'),
        ),
      ],
    );
  }
}