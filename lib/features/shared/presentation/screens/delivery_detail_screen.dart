import 'package:flutter/material.dart';
import 'package:ods_app/data/models/delivery_item.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../widgets/widgets.dart';
import '../../../distributor/presentation/widgets/payment_action_section.dart';

/// Shared delivery-detail screen.
///
/// Displays the common fields of a [Delivery] in a structured layout:
///   - Header (tracking ID, status, service type)
///   - Timeline (paid / assigned / picked up / delivered)
///   - Pickup & destination addresses
///   - Recipient (Send + Regional)
///   - Items list
///   - Payment summary
///   - Distributor-only payment action (when [showDistributorPayment])
///   - [extraSections] appended at the bottom for role-specific content
///
/// Each role opens this from its own list and supplies its own
/// `onRefresh` (or `null` for a static view) plus any extra widgets.
class DeliveryDetailScreen extends StatefulWidget {
  /// The initial delivery — typically the one the user tapped in the list.
  final Delivery delivery;

  /// Optional async refresh; called by pull-to-refresh. Return the
  /// updated delivery, or null on failure to keep the current one.
  final Future<Delivery?> Function()? onRefresh;

  /// Role-specific widgets rendered below the shared sections.
  /// Manager passes [] for now; Distributor/Rider will add actions.
  final List<Widget> extraSections;

  /// When true, renders a payment-action section at the bottom for
  /// `pending_payment` deliveries (Phase 11.5). Distributor opens this
  /// with `true`; every other role leaves it `false` — they never pay
  /// for a delivery directly.
  final bool showDistributorPayment;

  const DeliveryDetailScreen({
    super.key,
    required this.delivery,
    this.onRefresh,
    this.extraSections = const [],
    this.showDistributorPayment = false,
  });

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  late Delivery _delivery;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _delivery = widget.delivery;
  }

  Future<void> _refresh() async {
    if (widget.onRefresh == null) return;
    setState(() => _refreshing = true);
    try {
      final updated = await widget.onRefresh!();
      if (!mounted) return;
      if (updated != null) setState(() => _delivery = updated);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _delivery;

    return Scaffold(
      appBar: AppBar(title: Text(d.trackingId)),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh == null
            ? () async {}
            : _refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _HeaderCard(delivery: d),
            const SizedBox(height: AppSpacing.lg),
            _TimelineSection(delivery: d),
            const SizedBox(height: AppSpacing.lg),
            _RouteSection(delivery: d),
            if (d.recipientName != null || d.recipientPhone != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _RecipientSection(delivery: d),
            ],
            if (d.items != null && d.items!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _ItemsSection(delivery: d),
            ],
            const SizedBox(height: AppSpacing.lg),
            PaymentSummary(delivery: d),
            // Phase 11.5 — Distributor payment CTA (pending_payment only).
            if (widget.showDistributorPayment &&
                d.status == DeliveryStatus.pending_payment) ...[
              const SizedBox(height: AppSpacing.lg),
              PaymentActionSection(
                delivery: d,
                onRefresh: _refresh,
              ),
            ],
            if (d.notes != null && d.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _NotesSection(notes: d.notes!),
            ],
            if (widget.extraSections.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              ...widget.extraSections,
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final Delivery delivery;
  const _HeaderCard({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ServiceBadge(serviceType: delivery.serviceType),
              const Spacer(),
              DeliveryStatusChip(status: delivery.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            delivery.trackingId,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _formatDateRange(delivery),
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange(Delivery d) {
    final created = d.createdAt;
    if (created == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Created ${created.day} ${months[created.month - 1]} ${created.year}';
  }
}

class _ServiceBadge extends StatelessWidget {
  final ServiceType serviceType;
  const _ServiceBadge({required this.serviceType});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (serviceType) {
      ServiceType.receive => (Icons.call_received_rounded, AppColors.primary),
      ServiceType.send => (Icons.call_made_rounded, AppColors.accent),
      ServiceType.regional => (Icons.local_shipping_rounded, AppColors.info),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          serviceType.displayLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Timeline
// ─────────────────────────────────────────────────────────────

class _TimelineSection extends StatelessWidget {
  final Delivery delivery;
  const _TimelineSection({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final events = <_TimelineEvent>[];
    final d = delivery;

    if (d.assignedAt != null) {
      events.add(_TimelineEvent(
        label: 'Assigned',
        timestamp: d.assignedAt!,
        isComplete: true,
      ));
    }
    if (d.acceptedAt != null) {
      events.add(_TimelineEvent(
        label: 'Accepted',
        timestamp: d.acceptedAt!,
        isComplete: true,
      ));
    }
    if (d.pickedUpAt != null) {
      events.add(_TimelineEvent(
        label: 'Picked up',
        timestamp: d.pickedUpAt!,
        isComplete: true,
      ));
    }
    if (d.dispatchedAt != null) {
      events.add(_TimelineEvent(
        label: 'Dispatched',
        timestamp: d.dispatchedAt!,
        isComplete: true,
      ));
    }
    if (d.deliveredAt != null) {
      events.add(_TimelineEvent(
        label: 'Delivered',
        timestamp: d.deliveredAt!,
        isComplete: true,
      ));
    }
    if (d.cancelledAt != null) {
      events.add(_TimelineEvent(
        label: 'Cancelled',
        timestamp: d.cancelledAt!,
        isComplete: true,
        isCancelled: true,
      ));
    }

    if (events.isEmpty) return const SizedBox.shrink();

    return _SurfaceCard(
      children: [
        const _SectionTitle(icon: Icons.timeline_rounded, title: 'Progress'),
        const SizedBox(height: AppSpacing.xs),
        ...events.map((e) => _TimelineRow(event: e)),
      ],
    );
  }
}

class _TimelineEvent {
  final String label;
  final DateTime timestamp;
  final bool isComplete;
  final bool isCancelled;

  const _TimelineEvent({
    required this.label,
    required this.timestamp,
    required this.isComplete,
    this.isCancelled = false,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineEvent event;
  const _TimelineRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = event.isCancelled ? AppColors.error : AppColors.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            event.isCancelled
                ? Icons.cancel_rounded
                : Icons.check_circle_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              event.label,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            _formatTimestamp(event.timestamp),
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} · '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────
// Route
// ─────────────────────────────────────────────────────────────

class _RouteSection extends StatelessWidget {
  final Delivery delivery;
  const _RouteSection({required this.delivery});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      const _SectionTitle(icon: Icons.place_rounded, title: 'Route'),
      const SizedBox(height: AppSpacing.sm),
      _RouteRow(
        icon: Icons.storefront_rounded,
        label: 'Pickup',
        value: _pickupLine(),
      ),
      const SizedBox(height: AppSpacing.xs),
      _RouteRow(
        icon: Icons.location_on_rounded,
        label: 'Destination',
        value: _destinationLine(),
      ),
      if (delivery.isRegional &&
          delivery.destinationBusStop != null) ...[
        const SizedBox(height: AppSpacing.xs),
        _RouteRow(
          icon: Icons.directions_bus_rounded,
          label: 'Bus stop',
          value: delivery.destinationBusStop!,
        ),
      ],
    ]);
  }

  String _pickupLine() {
    final d = delivery;
    if (d.pickupAddress != null && d.pickupAddress!.isNotEmpty) {
      return d.pickupAddress!;
    }
    if (d.pickupBranchId != null) {
      return 'Branch #${d.pickupBranchId}';
    }
    return '—';
  }

  String _destinationLine() {
    final d = delivery;
    if (d.isRegional) {
      final parts = <String>[];
      if (d.destinationRegion != null) parts.add(d.destinationRegion!);
      if (d.destinationDistrict != null) parts.add(d.destinationDistrict!);
      return parts.isNotEmpty ? parts.join(' · ') : '—';
    }
    return d.destinationAddress ?? '—';
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _RouteRow({
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
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Recipient
// ─────────────────────────────────────────────────────────────

class _RecipientSection extends StatelessWidget {
  final Delivery delivery;
  const _RecipientSection({required this.delivery});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      const _SectionTitle(icon: Icons.person_rounded, title: 'Recipient'),
      const SizedBox(height: AppSpacing.sm),
      if (delivery.recipientName != null)
        _kv(context, 'Name', delivery.recipientName!),
      if (delivery.recipientPhone != null)
        _kv(context, 'Phone', delivery.recipientPhone!),
    ]);
  }

  Widget _kv(BuildContext context, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Items
// ─────────────────────────────────────────────────────────────

class _ItemsSection extends StatelessWidget {
  final Delivery delivery;
  const _ItemsSection({required this.delivery});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      _SectionTitle(
        icon: Icons.inventory_2_rounded,
        title: 'Items (${delivery.items!.length})',
      ),
      const SizedBox(height: AppSpacing.sm),
      ...delivery.items!.map((item) => _ItemRow(item: item)),
    ]);
  }
}

class _ItemRow extends StatelessWidget {
  final DeliveryItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          const Icon(
            Icons.check_box_outlined,
            size: 14,
            color: AppColors.onSurfaceMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              item.displayLabel,
              style: text.bodyMedium,
            ),
          ),
          if (item.productCode != null)
            Text(
              item.productCode!,
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Notes
// ─────────────────────────────────────────────────────────────

class _NotesSection extends StatelessWidget {
  final String notes;
  const _NotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      const _SectionTitle(icon: Icons.sticky_note_2_rounded, title: 'Notes'),
      const SizedBox(height: AppSpacing.xs),
      Text(notes, style: Theme.of(context).textTheme.bodyMedium),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Shared
// ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final List<Widget> children;
  const _SurfaceCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}