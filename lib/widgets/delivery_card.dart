import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../data/models/delivery.dart';
import 'delivery_status_chip.dart';

/// A list-row card showing a delivery's essential information.
///
/// Used by:
///   - Distributor "My deliveries" (Phase 7)
///   - Manager "Branch deliveries" (Phase 6)
///   - Rider "Tasks" (Phase 8)
///
/// Layout:
///   [Service icon + label]              [Status chip]
///   Tracking ID
///   →  Destination line
///   [Fee amount]                         [Time ago / trailing]
///
/// The destination line adapts to the service:
///   Receive  → destination address ("To your location" if null)
///   Send     → "To {recipientName}" (or destination address)
///   Regional → "{region} · {district}"
///
/// All visual styling comes from the ODS theme — no per-screen overrides
/// needed. Override [trailing] to replace the "time ago" text with any
/// widget (e.g., a "Track" button).
class DeliveryCard extends StatelessWidget {
  final Delivery delivery;

  /// Called when the card is tapped. If null, the card is not tappable.
  final VoidCallback? onTap;

  /// Replaces the "time ago" text at the bottom-right with a custom widget.
  /// Useful for action buttons in contexts where the card is a full row.
  final Widget? trailing;

  /// When true and the delivery is a `send`, the recipient's name is
  /// used in the destination line. Set to false in Manager views where
  /// recipient PII should be hidden until the detail screen opens.
  final bool showRecipient;

  const DeliveryCard({
    super.key,
    required this.delivery,
    this.onTap,
    this.trailing,
    this.showRecipient = true,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Service badge + status chip ──────────────────
              Row(
                children: [
                  _ServiceBadge(serviceType: delivery.serviceType),
                  const Spacer(),
                  DeliveryStatusChip(status: delivery.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // ─── Tracking ID ─────────────────────────────────
              Text(
                delivery.trackingId,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),

              // ─── Destination line ────────────────────────────
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: AppColors.onSurfaceMuted,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      _destinationLine(),
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // ─── Fee + timestamp / trailing ──────────────────
              Row(
                children: [
                  Text(
                    delivery.totalAmountLabel,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  trailing ??
                      Text(
                        _relativeTime(delivery.createdAt),
                        style: text.bodySmall?.copyWith(
                          color: AppColors.onSurfaceSubtle,
                        ),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _destinationLine() {
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

    if (delivery.isSend) {
      if (showRecipient && delivery.recipientName != null) {
        return 'To ${delivery.recipientName}';
      }
      if (delivery.destinationAddress != null) {
        return delivery.destinationAddress!;
      }
      return 'To recipient';
    }

    // Receive
    return delivery.destinationAddress ?? 'To your location';
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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
      ServiceType.regional =>
        (Icons.local_shipping_rounded, AppColors.info),
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