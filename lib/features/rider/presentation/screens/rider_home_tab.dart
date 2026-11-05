import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../widgets/widgets.dart';
import '../providers/rider_dashboard_providers.dart';

/// The Rider's Home tab — command-center overview.
///
/// Shows: KPI grid (available / active / delivered today / total),
/// earnings mini-card, current active task (if any), and recent
/// activity. Full accept/pickup/deliver actions live on the Tasks and
/// Active tabs (8.3 / 8.4) — Home is read-only snapshot for now.
class RiderHomeTab extends ConsumerWidget {
  const RiderHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(riderHomeProvider);

    return homeAsync.when(
      loading: () => const LoadingView(message: 'Loading your dashboard…'),
      error: (_, __) => ErrorView(
        message: 'Could not load your dashboard.',
        onRetry: () => ref.invalidate(riderHomeProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(riderHomeProvider);
          await ref.read(riderHomeProvider.future);
        },
        child: _Content(data: data),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final RiderHomeData data;
  const _Content({required this.data});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kpis = data.kpis;
    final activeTask = data.activeTask;
    final recent = data.recentDeliveries;
    final isEmpty = recent.isEmpty && activeTask == null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'Your tasks',
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          _formatDate(DateTime.now()),
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ─── KPI grid ───────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.assignment_rounded,
                label: 'Available',
                value: '${kpis.tasks.available}',
                isHighlighted: kpis.tasks.available > 0,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.delivery_dining_rounded,
                label: 'Active',
                value: '${kpis.tasks.active}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.check_circle_rounded,
                label: 'Delivered today',
                value: '${kpis.tasks.deliveredToday}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.inventory_2_rounded,
                label: 'Total delivered',
                value: '${kpis.tasks.totalDelivered}',
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Earnings ───────────────────────────────────────
        const _SectionHeader(
          title: 'Earnings',
          icon: Icons.payments_rounded,
        ),
        const SizedBox(height: AppSpacing.xs),
        _EarningsCard(
          thisMonthTsh: kpis.earnings.thisMonthTsh,
          pendingTsh: kpis.earnings.pendingTsh,
        ),

        // ─── Active task ────────────────────────────────────
        if (activeTask != null) ...[
          const SizedBox(height: AppSpacing.xl),
          const _SectionHeader(
            title: 'Active task',
            icon: Icons.timer_rounded,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ActiveTaskCard(delivery: activeTask),
        ],

        // ─── Recent activity ────────────────────────────────
        if (recent.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const _SectionHeader(
            title: 'Recent activity',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final d in recent) ...[
            DeliveryCard(delivery: d),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],

        // ─── Empty state ────────────────────────────────────
        if (isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const _EmptyState(),
        ],

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KPI tile — mirrors DistributorHomeTab._KpiTile
// ─────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isHighlighted;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final valueColor = isHighlighted ? AppColors.warning : AppColors.onSurface;
    final iconColor = isHighlighted ? AppColors.warning : AppColors.primary;

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
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Earnings mini-card
// ─────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  final double thisMonthTsh;
  final double pendingTsh;
  const _EarningsCard({
    required this.thisMonthTsh,
    required this.pendingTsh,
  });

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This month',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _formatTsh(thisMonthTsh),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: AppColors.borderSubtle,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _formatTsh(pendingTsh),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: pendingTsh > 0
                          ? AppColors.warning
                          : AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Active task hero
// ─────────────────────────────────────────────────────────────

class _ActiveTaskCard extends StatelessWidget {
  final Delivery delivery;
  const _ActiveTaskCard({required this.delivery});

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
          if (delivery.recipientName != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _kv(
              context,
              Icons.person_outline_rounded,
              delivery.recipientName!,
            ),
          ],
          if (_destinationLabel(delivery) != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            _kv(
              context,
              Icons.place_outlined,
              _destinationLabel(delivery)!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, IconData icon, String value) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.onSurfaceMuted),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            value,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String? _destinationLabel(Delivery d) {
    if (d.isRegional) {
      final parts = <String>[];
      if (d.destinationRegion != null) parts.add(d.destinationRegion!);
      if (d.destinationDistrict != null) parts.add(d.destinationDistrict!);
      if (parts.isNotEmpty) return parts.join(' · ');
      return 'Regional destination';
    }
    if (d.isSend && d.recipientName != null) return d.destinationAddress;
    return d.destinationAddress;
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
                Icons.assignment_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No tasks yet',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'New tasks will appear here when a delivery is assigned to you.',
              style: text.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────────────────────────

String _formatTsh(double amount) {
  if (amount >= 1000000) {
    return 'TZS ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 10000) {
    return 'TZS ${(amount / 1000).toStringAsFixed(1)}k';
  }
  return 'TZS ${amount.toStringAsFixed(0)}';
}

String _formatDate(DateTime dt) {
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
}