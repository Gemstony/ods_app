import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../data/models/dispatcher_ticket.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';
import '../providers/receiver_regional_providers.dart';

/// The Receiver's Regional tab — regional deliveries at the branch, with
/// the two-step dispatch flow:
///
///   batched  → Assign to me   → assigned
///   assigned → Dispatch       → dispatched (+ ticket)
///   dispatched               → read-only ticket view
///
/// Gated on `dispatcher_enabled`. Non-dispatchers see an info card.
///
/// Busy state is scoped to API calls only — never overlaps with a
/// dialog (matches 9.2's pattern to avoid pumpAndSettle hangs).
class ReceiverRegionalTab extends ConsumerStatefulWidget {
  const ReceiverRegionalTab({super.key});

  @override
  ConsumerState<ReceiverRegionalTab> createState() =>
      _ReceiverRegionalTabState();
}

class _ReceiverRegionalTabState extends ConsumerState<ReceiverRegionalTab> {
  /// Delivery IDs with an in-flight assign or dispatch call.
  final Set<int> _busyIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    // Gate: dispatcher privileges required (backend 403s otherwise).
    if (user == null || !user.dispatcherEnabled) {
      return const _DispatcherGateMessage();
    }

    final async = ref.watch(receiverRegionalProvider);

    return async.when(
      loading: () => const LoadingView(message: 'Loading regional deliveries…'),
      error: (_, __) => ErrorView(
        message: 'Could not load regional deliveries.',
        onRetry: () => ref.invalidate(receiverRegionalProvider),
      ),
      data: (_) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final filter = ref.watch(receiverRegionalFilterProvider);
    final filtered = ref.watch(filteredReceiverRegionalProvider);
    final hasAny =
        (ref.watch(receiverRegionalProvider).valueOrNull ?? const [])
            .isNotEmpty;

    return Column(
      children: [
        _FilterBar(
          filter: filter,
          onChanged: (s) =>
              ref.read(receiverRegionalFilterProvider.notifier).setStatus(s),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(receiverRegionalProvider);
              await ref.read(receiverRegionalProvider.future);
            },
            child: filtered.isEmpty
                ? _buildEmptyScrollable(hasAny: hasAny)
                : _buildList(filtered),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Delivery> regional) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: regional.length,
      itemBuilder: (context, i) {
        final delivery = regional[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _RegionalDeliveryCard(
            delivery: delivery,
            isBusy: _busyIds.contains(delivery.id),
            onAssign: () => _onAssignTap(delivery),
            onDispatch: () => _onDispatchTap(delivery),
          ),
        );
      },
    );
  }

  Widget _buildEmptyScrollable({required bool hasAny}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        const SizedBox(height: 80),
        hasAny
            ? _FilterEmptyState(
                onClear: () => ref
                    .read(receiverRegionalFilterProvider.notifier)
                    .clear(),
              )
            : const _NoRegionalState(),
      ],
    );
  }

  // ─── Assign flow (single API call, no confirm) ────────────
  Future<void> _onAssignTap(Delivery delivery) async {
    setState(() => _busyIds.add(delivery.id));

    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.assignRegionalDispatcher(delivery.id);

    if (!mounted) return;
    setState(() => _busyIds.remove(delivery.id));

    result.fold(
      onSuccess: (_) {
        ref.invalidate(receiverRegionalProvider);
        _showSnackbar('Dispatcher assigned. Ready to dispatch.');
      },
      onFailure: (f) => _showSnackbar(f.message),
    );
  }

  // ─── Dispatch flow (form dialog then API) ─────────────────
  Future<void> _onDispatchTap(Delivery delivery) async {
    final form = await showDialog<_DispatchFormResult>(
      context: context,
      builder: (_) => _DispatchFormDialog(delivery: delivery),
    );
    if (form == null || !mounted) return;

    setState(() => _busyIds.add(delivery.id));

    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.dispatchRegionalProvider(
      delivery.id,
      providerName: form.providerName,
      providerType: form.providerType,
      ticketNumber: form.ticketNumber,
      routeFrom: form.routeFrom,
      routeTo: form.routeTo,
      transportFare: form.transportFare,
      notes: form.notes,
    );

    if (!mounted) return;
    setState(() => _busyIds.remove(delivery.id));

    result.fold(
      onSuccess: (d) {
        ref.invalidate(receiverRegionalProvider);
        final ticketNum = d.dispatcherTicket?.ticketNumber ?? 'created';
        _showSnackbar('Dispatched via ${form.providerName}. Ticket $ticketNum.');
      },
      onFailure: (f) => _showSnackbar(f.message),
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
  final ReceiverRegionalFilter filter;
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
            _chip('Batched', DeliveryStatus.batched),
            const SizedBox(width: 6),
            _chip('Assigned', DeliveryStatus.assigned),
            const SizedBox(width: 6),
            _chip('Dispatched', DeliveryStatus.dispatched),
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
// Regional delivery card
// ─────────────────────────────────────────────────────────────

class _RegionalDeliveryCard extends StatelessWidget {
  final Delivery delivery;
  final bool isBusy;
  final VoidCallback onAssign;
  final VoidCallback onDispatch;

  const _RegionalDeliveryCard({
    required this.delivery,
    required this.isBusy,
    required this.onAssign,
    required this.onDispatch,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ticket = delivery.dispatcherTicket;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: delivery.status == DeliveryStatus.dispatched
              ? AppColors.success
              : AppColors.border,
          width: delivery.status == DeliveryStatus.dispatched ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header ─────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.local_shipping_rounded,
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
          _destinationLine(context),

          // ─── Recipient ──────────────────────────────────
          if (delivery.recipientName != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            _InfoRow(
              icon: Icons.person_outline_rounded,
              value: delivery.recipientName!,
            ),
          ],

          // ─── Bus cargo fare (pre-dispatch estimate) ─────
          if (delivery.busCargoFare != null &&
              delivery.status != DeliveryStatus.dispatched) ...[
            const SizedBox(height: AppSpacing.xxs),
            _InfoRow(
              icon: Icons.payments_outlined,
              value:
                  'Est. transport fare: ${delivery.currency} ${delivery.busCargoFare!.toStringAsFixed(0)}',
            ),
          ],

          // ─── Ticket block (dispatched only) ─────────────
          if (ticket != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _TicketBlock(ticket: ticket),
          ],

          // ─── CTA ────────────────────────────────────────
          if (delivery.status == DeliveryStatus.batched) ...[
            const SizedBox(height: AppSpacing.md),
            _ActionButton(
              label: 'Assign to me',
              icon: Icons.how_to_reg_rounded,
              isBusy: isBusy,
              onPressed: onAssign,
            ),
          ] else if (delivery.status == DeliveryStatus.assigned) ...[
            const SizedBox(height: AppSpacing.md),
            _ActionButton(
              label: 'Dispatch via provider',
              icon: Icons.local_shipping_rounded,
              isBusy: isBusy,
              onPressed: onDispatch,
            ),
          ],
        ],
      ),
    );
  }

  Widget _destinationLine(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final parts = <String>[];
    if (delivery.destinationRegion != null) parts.add(delivery.destinationRegion!);
    if (delivery.destinationDistrict != null) parts.add(delivery.destinationDistrict!);
    if (delivery.destinationBusStop != null) parts.add(delivery.destinationBusStop!);
    final value = parts.isEmpty ? 'Regional destination' : parts.join(' · ');
    return Row(
      children: [
        const Icon(Icons.place_outlined, size: 14, color: AppColors.onSurfaceMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            value,
            style: text.bodySmall?.copyWith(color: AppColors.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
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
            style: text.bodySmall?.copyWith(color: AppColors.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TicketBlock extends StatelessWidget {
  final DispatcherTicket ticket;
  const _TicketBlock({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.confirmation_number_rounded,
                size: 14,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${ticket.ticketNumber} · ${ticket.providerName}',
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${ticket.providerTypeLabel} · '
            '${ticket.routeFrom} → ${ticket.routeTo}',
            style: text.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: 2),
          Text(
            'Transport fare: ${ticket.transportFareLabel}',
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isBusy;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isBusy,
    required this.onPressed,
  });

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
// Dispatch form dialog
// ─────────────────────────────────────────────────────────────

class _DispatchFormResult {
  final String providerName;
  final String providerType;
  final String ticketNumber;
  final String routeFrom;
  final String routeTo;
  final double? transportFare;
  final String? notes;

  const _DispatchFormResult({
    required this.providerName,
    required this.providerType,
    required this.ticketNumber,
    required this.routeFrom,
    required this.routeTo,
    this.transportFare,
    this.notes,
  });
}

class _DispatchFormDialog extends StatefulWidget {
  final Delivery delivery;
  const _DispatchFormDialog({required this.delivery});

  @override
  State<_DispatchFormDialog> createState() => _DispatchFormDialogState();
}

class _DispatchFormDialogState extends State<_DispatchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _providerName;
  late final TextEditingController _ticketNumber;
  late final TextEditingController _routeFrom;
  late final TextEditingController _routeTo;
  late final TextEditingController _fare;
  late final TextEditingController _notes;
  String _providerType = 'bus';

  @override
  void initState() {
    super.initState();
    _providerName = TextEditingController();
    _ticketNumber = TextEditingController();
    _routeFrom = TextEditingController();
    _routeTo = TextEditingController(
      text: widget.delivery.destinationRegion ?? '',
    );
    _fare = TextEditingController(
      text: widget.delivery.busCargoFare?.toStringAsFixed(0) ?? '',
    );
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _providerName.dispose();
    _ticketNumber.dispose();
    _routeFrom.dispose();
    _routeTo.dispose();
    _fare.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final fareText = _fare.text.trim();
    final fare = fareText.isEmpty ? null : double.tryParse(fareText);

    Navigator.of(context).pop(_DispatchFormResult(
      providerName: _providerName.text.trim(),
      providerType: _providerType,
      ticketNumber: _ticketNumber.text.trim(),
      routeFrom: _routeFrom.text.trim(),
      routeTo: _routeTo.text.trim(),
      transportFare: fare,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Dispatch ${widget.delivery.trackingId}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _providerName,
                  decoration: const InputDecoration(
                    labelText: 'Provider name',
                    hintText: 'e.g. Kilimanjaro Express',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _providerType,
                  decoration: const InputDecoration(
                    labelText: 'Provider type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'bus', child: Text('Bus')),
                    DropdownMenuItem(value: 'cargo', child: Text('Cargo')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _providerType = v);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ticketNumber,
                  decoration: const InputDecoration(
                    labelText: 'Ticket number',
                    hintText: 'e.g. TKT-1234',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _routeFrom,
                  decoration: const InputDecoration(
                    labelText: 'Route from',
                    hintText: 'e.g. Dar es Salaam',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _routeTo,
                  decoration: const InputDecoration(
                    labelText: 'Route to',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fare,
                  decoration: const InputDecoration(
                    labelText: 'Transport fare (optional)',
                    hintText: 'Leave blank to use estimate',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    final n = double.tryParse(t);
                    if (n == null || n < 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Dispatch'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Non-dispatcher gate
// ─────────────────────────────────────────────────────────────

class _DispatcherGateMessage extends StatelessWidget {
  const _DispatcherGateMessage();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.surface,
              child: Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Dispatcher access required',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ask your branch manager to enable Regional Dispatcher '
              'privileges on your account to manage regional dispatch.',
              style: text.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────────────────────

class _NoRegionalState extends StatelessWidget {
  const _NoRegionalState();

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
            Icons.local_shipping_outlined,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No regional deliveries',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Regional deliveries ready for dispatch will appear here.',
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
          'No deliveries match your filter',
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