import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';
import '../providers/rider_dashboard_providers.dart';
import '../providers/rider_tasks_providers.dart';

/// The Rider's Tasks tab — full list of assigned + in-progress + delivered
/// deliveries with the accept flow.
///
/// A delivery in `assigned` state shows an inline Accept button. Tapping
/// opens a confirm dialog; on confirm, the API is called, a per-tile
/// spinner shows, and on success the list refreshes with a snackbar
/// pointing the rider to the Active tab (Phase 8.4) to pick it up.
class RiderTasksTab extends ConsumerStatefulWidget {
  const RiderTasksTab({super.key});

  @override
  ConsumerState<RiderTasksTab> createState() => _RiderTasksTabState();
}

class _RiderTasksTabState extends ConsumerState<RiderTasksTab> {
  /// Delivery IDs with an in-flight accept request. Rendering a spinner
  /// on just those tiles keeps the rest of the list interactive.
  final Set<int> _acceptingIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(riderTasksProvider);

    return tasksAsync.when(
      loading: () => const LoadingView(message: 'Loading your tasks…'),
      error: (_, __) => ErrorView(
        message: 'Could not load your tasks.',
        onRetry: () => ref.invalidate(riderTasksProvider),
      ),
      data: (_) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final filter = ref.watch(riderTasksFilterProvider);
    final filtered = ref.watch(filteredRiderTasksProvider);
    final hasTasks = (ref.watch(riderTasksProvider).valueOrNull ?? const [])
        .isNotEmpty;

    return Column(
      children: [
        _FilterBar(
          filter: filter,
          onStatusChanged: (s) =>
              ref.read(riderTasksFilterProvider.notifier).setStatus(s),
          onServiceTypeChanged: (s) =>
              ref.read(riderTasksFilterProvider.notifier).setServiceType(s),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(riderTasksProvider);
              await ref.read(riderTasksProvider.future);
            },
            child: filtered.isEmpty
                ? _buildEmptyScrollable(
                    hasTasks: hasTasks,
                    filter: filter,
                  )
                : _buildTaskList(filtered),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList(List<Delivery> tasks) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final delivery = tasks[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: DeliveryCard(
            delivery: delivery,
            trailing: delivery.status == DeliveryStatus.assigned
                ? _AcceptButton(
                    isAccepting: _acceptingIds.contains(delivery.id),
                    onPressed: () => _onAcceptTap(delivery),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildEmptyScrollable({
    required bool hasTasks,
    required RiderTasksFilter filter,
  }) {
    // Wrapped in a ListView so RefreshIndicator can still trigger on an
    // empty list. The SizedBox pushes the content to a pleasant vertical
    // position rather than hugging the top.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        const SizedBox(height: 80),
        hasTasks
            ? _FilterEmptyState(
                filter: filter,
                onClear: () =>
                    ref.read(riderTasksFilterProvider.notifier).clear(),
              )
            : const _NoTasksState(),
      ],
    );
  }

  Future<void> _onAcceptTap(Delivery delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept this task?'),
        content: Text(
          'You are accepting to deliver ${delivery.trackingId}. '
          'Be ready to pick it up from the branch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _acceptingIds.add(delivery.id));

    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.acceptRiderDelivery(delivery.id);

    if (!mounted) return;
    setState(() => _acceptingIds.remove(delivery.id));

    result.fold(
      onSuccess: (_) {
        ref.invalidate(riderTasksProvider);
        ref.invalidate(riderHomeProvider);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text(
              'Task accepted. Open the Active tab to pick it up.',
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
}

// ─────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final RiderTasksFilter filter;
  final ValueChanged<DeliveryStatus?> onStatusChanged;
  final ValueChanged<ServiceType?> onServiceTypeChanged;

  const _FilterBar({
    required this.filter,
    required this.onStatusChanged,
    required this.onServiceTypeChanged,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status chips (horizontally scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusChip('All', null),
                const SizedBox(width: 6),
                _statusChip('Assigned', DeliveryStatus.assigned),
                const SizedBox(width: 6),
                _statusChip('Accepted', DeliveryStatus.accepted),
                const SizedBox(width: 6),
                _statusChip('Picked up', DeliveryStatus.picked_up),
                const SizedBox(width: 6),
                _statusChip('Delivered', DeliveryStatus.delivered),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Service type dropdown
          Row(
            children: [
              const Text(
                'Service:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              DropdownButtonHideUnderline(
                child: DropdownButton<ServiceType?>(
                  value: filter.serviceType,
                  isDense: true,
                  onChanged: onServiceTypeChanged,
                  items: const [
                    DropdownMenuItem<ServiceType?>(
                      value: null,
                      child: Text('All', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem<ServiceType?>(
                      value: ServiceType.receive,
                      child: Text('Receive', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem<ServiceType?>(
                      value: ServiceType.send,
                      child: Text('Send', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem<ServiceType?>(
                      value: ServiceType.regional,
                      child: Text('Regional', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, DeliveryStatus? status) {
    final selected = filter.status == status;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onStatusChanged(status),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Accept button (with in-tile loading state)
// ─────────────────────────────────────────────────────────────

class _AcceptButton extends StatelessWidget {
  final bool isAccepting;
  final VoidCallback onPressed;

  const _AcceptButton({
    required this.isAccepting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isAccepting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('Accept'),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────────────────────

class _NoTasksState extends StatelessWidget {
  const _NoTasksState();

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
            Icons.assignment_outlined,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No tasks yet',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'New tasks will appear here when a delivery is assigned to you.',
          style: text.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FilterEmptyState extends StatelessWidget {
  final RiderTasksFilter filter;
  final VoidCallback onClear;

  const _FilterEmptyState({required this.filter, required this.onClear});

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
          'No tasks match your filter',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Try a different status or service type.',
          style: text.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear_rounded, size: 18),
          label: const Text('Clear filters'),
        ),
      ],
    );
  }
}