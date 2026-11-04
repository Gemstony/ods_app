import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// The three delivery service types a Distributor can choose when creating
/// a new delivery.
enum DeliveryServiceChoice { receive, send, regional }

/// A bottom sheet that lets the Distributor pick which delivery service
/// they want to create a new request for.
///
/// Returns a [DeliveryServiceChoice] via [Navigator.pop] when the user taps
/// one of the service cards, or `null` if the sheet is dismissed.
class ServicePickerSheet extends StatelessWidget {
  const ServicePickerSheet({super.key});

  /// Convenience helper to show the sheet and await the user's selection.
  static Future<DeliveryServiceChoice?> show(BuildContext context) {
    return showModalBottomSheet<DeliveryServiceChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ServicePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'New delivery',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the service you need.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                _ServiceCard(
                  icon: Icons.inbox_rounded,
                  color: AppColors.primary,
                  title: 'Receive',
                  description:
                      'Receive parcels or products sent to you at a branch.',
                  onTap: () => Navigator.of(context)
                      .pop(DeliveryServiceChoice.receive),
                ),
                const SizedBox(height: 12),
                _ServiceCard(
                  icon: Icons.send_rounded,
                  color: AppColors.accent,
                  title: 'Send',
                  description:
                      'Send a package to a recipient anywhere in Tanzania.',
                  onTap: () =>
                      Navigator.of(context).pop(DeliveryServiceChoice.send),
                ),
                const SizedBox(height: 12),
                _ServiceCard(
                  icon: Icons.local_shipping_rounded,
                  color: AppColors.info,
                  title: 'Regional',
                  description:
                      'Send goods to another region via bus or cargo carrier.',
                  onTap: () =>
                      Navigator.of(context).pop(DeliveryServiceChoice.regional),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}