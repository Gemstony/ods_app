import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';

/// Which wizard to open from the FAB.
enum DeliveryServiceChoice { receive, send, regional }

/// Shows a modal sheet for choosing the delivery service type.
///
/// In 7.4 only Receive and Send are available. Regional will appear in
/// 7.5 — this sheet gets one more card at that point.
Future<DeliveryServiceChoice?> showServicePickerSheet(
  BuildContext context,
) {
  return showModalBottomSheet<DeliveryServiceChoice>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => const _ServicePickerContent(),
  );
}

class _ServicePickerContent extends StatelessWidget {
  const _ServicePickerContent();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
            Text(
              'New delivery',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Choose a service to continue.',
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ServiceCard(
              icon: Icons.call_received_rounded,
              color: AppColors.primary,
              title: 'Receive',
              subtitle: 'From a pickup branch to your current location',
              onTap: () =>
                  Navigator.of(context).pop(DeliveryServiceChoice.receive),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ServiceCard(
              icon: Icons.call_made_rounded,
              color: AppColors.accent,
              title: 'Send',
              subtitle: 'From your location to a recipient',
              onTap: () =>
                  Navigator.of(context).pop(DeliveryServiceChoice.send),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ServiceCard(
              icon: Icons.local_shipping_rounded,
              color: AppColors.info,
              title: 'Regional',
              subtitle: 'To another city or region via bus or cargo',
              onTap: () =>
                  Navigator.of(context).pop(DeliveryServiceChoice.regional),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.onSurfaceSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
