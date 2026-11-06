import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../widgets/widgets.dart';
import '../providers/receiver_history_providers.dart';

/// The Receiver's History tab — completed handovers and dispatches.
///
/// Two sources merged:
///   - receive deliveries that were `picked_up` (released to a rider)
///   - regional deliveries that were `dispatched` (handed to a bus/cargo)
///     plus any that have since been `delivered`
///
/// Sorted by most recent meaningful action. Filter chips narrow by
/// final state. Tap a card does nothing yet — a detail screen for
/// history rows is Phase 14 territory.
class ReceiverHistoryTab extends ConsumerWidget {
  const ReceiverHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiverHistoryProvider);

    return async.when(
      loading: () => const LoadingView(message: 'Loading history…'),
      error: (_, __) => ErrorView(
        message: 'Could not load history.',
        onRetry: () => ref.invalidate(receiverHistoryProvider),
      ),
      data: (_) => _buildContent(context, ref),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(receiverHistoryFilterProvider);
    final filtered = ref.watch(filteredReceiverHistoryProvider);
    final hasAny =
        (ref.watch(receiverHistoryProvider).valueOrNull ?? const [])
            .isNotEmpty;

    return Column(
      children: [
        _FilterBar(
          filter: filter,
          onChanged: (s) =>
              ref.read(receiverHistoryFilterProvider.notifier).setStatus(s),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(receiverHistoryProvider);
              await ref.read(receiverHistoryProvider.future);
            },
            child: filtered.isEmpty
                ? _buildEmptyScrollable(hasAny: hasAny, ref: ref)
                : _buildList(filtered),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Delivery> history) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final delivery = history[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: DeliveryCard(
            delivery: delivery,
            trailing: _ActionTimestampTrailing(delivery: delivery),
          ),
        );
      },
    );
  }

  Widget _buildEmptyScrollable({
    required bool hasAny,
    required WidgetRef ref,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        const SizedBox(height: 80),
        hasAny
            ? _FilterEmptyState(
                onClear: () =>
                    ref.read(receiverHistoryFilterProvider.notifier).clear(),
              )
            : const _NoHistoryState(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final ReceiverHistoryFilter filter;
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
            _chip('Picked up', DeliveryStatus.picked_up),
            const SizedBox(width: 6),
            _chip('Dispatched', DeliveryStatus.dispatched),
            const SizedBox(width: 6),
            _chip('Delivered', DeliveryStatus.delivered),
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
// Trailing timestamp (action-specific)
// ─────────────────────────────────────────────────────────────

class _ActionTimestampTrailing extends StatelessWidget {
  final Delivery delivery;
  const _ActionTimestampTrailing({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = _actionLabel(delivery.status);
    final time = _actionTime(delivery);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label · ',
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceSubtle,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          _relativeTime(time),
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceSubtle,
          ),
        ),
      ],
    );
  }

  static String _actionLabel(DeliveryStatus status) => switch (status) {
        DeliveryStatus.picked_up => 'Released',
        DeliveryStatus.dispatched => 'Dispatched',
        DeliveryStatus.delivered => 'Delivered',
        _ => 'Updated',
      };

  static DateTime? _actionTime(Delivery d) => switch (d.status) {
        DeliveryStatus.picked_up =>
          d.pickedUpAt ?? d.updatedAt ?? d.createdAt,
        DeliveryStatus.dispatched =>
          d.dispatchedAt ?? d.updatedAt ?? d.createdAt,
        DeliveryStatus.delivered =>
          d.deliveredAt ?? d.updatedAt ?? d.createdAt,
        _ => d.updatedAt ?? d.createdAt,
      };

  static String _relativeTime(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────────────────────

class _NoHistoryState extends StatelessWidget {
  const _NoHistoryState();

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
            Icons.history_toggle_off_rounded,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No handovers yet',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Packages you release and regional deliveries you dispatch '
          'will appear here.',
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
          'No handovers match your filter',
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