import 'package:flutter/material.dart';

import '../data/models/delivery.dart';
import 'status_chip.dart';

/// Maps a [DeliveryStatus] to the semantic [StatusType] that determines
/// its color.
///
/// Rationale per status:
///   pending_payment → warning  (needs the user's action)
///   paid / batched  → primary  (in the ODS pipeline, brand color)
///   assigned / accepted → primary  (rider is engaged)
///   picked_up / dispatched → info  (in motion, informational)
///   delivered       → success  (done)
///   cancelled       → neutral  (intentional, not an error)
///   failed / expired → error   (something went wrong)
///   unknown         → neutral  (defensive fallback)
StatusType _typeFor(DeliveryStatus status) => switch (status) {
      DeliveryStatus.pending_payment => StatusType.warning,
      DeliveryStatus.paid => StatusType.primary,
      DeliveryStatus.batched => StatusType.primary,
      DeliveryStatus.assigned => StatusType.primary,
      DeliveryStatus.accepted => StatusType.primary,
      DeliveryStatus.picked_up => StatusType.info,
      DeliveryStatus.dispatched => StatusType.info,
      DeliveryStatus.delivered => StatusType.success,
      DeliveryStatus.cancelled => StatusType.neutral,
      DeliveryStatus.failed => StatusType.error,
      DeliveryStatus.expired => StatusType.error,
      DeliveryStatus.unknown => StatusType.neutral,
    };

/// Shows a delivery's lifecycle status as a colored chip.
///
/// Wraps the existing [StatusChip] from Phase 1.7 — the only new thing
/// is the [DeliveryStatus] → [StatusType] color mapping.
class DeliveryStatusChip extends StatelessWidget {
  final DeliveryStatus status;
  final bool isCompact;
  final IconData? icon;

  const DeliveryStatusChip({
    super.key,
    required this.status,
    this.isCompact = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: status.displayLabel,
      type: _typeFor(status),
      isCompact: isCompact,
      icon: icon,
    );
  }
}