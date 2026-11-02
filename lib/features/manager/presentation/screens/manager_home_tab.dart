import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/manager_dashboard_kpis.dart';
import '../../../../widgets/widgets.dart';
import '../providers/manager_dashboard_providers.dart';

/// The Manager's Home tab — operational command center for their branch.
///
/// Shows:
///   - Branch header (name, code, status chip)
///   - "Inactive branch" warning if applicable
///   - 4 KPI tiles: waiting pickup / in transit / today / delivered today
///   - Revenue today
///   - Team breakdown
///
/// All data comes from `GET /manager/dashboard` and is branch-scoped.
/// Pull-to-refresh invalidates the provider.
class ManagerHomeTab extends ConsumerWidget {
  const ManagerHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(managerDashboardProvider);

    return kpisAsync.when(
      loading: () => const LoadingView(message: 'Loading branch data…'),
      error: (_, __) => ErrorView(
        message: 'Could not load your branch dashboard.',
        onRetry: () => ref.invalidate(managerDashboardProvider),
      ),
      data: (kpis) {
        if (!kpis.hasBranch) {
          return const EmptyView(
            title: 'No branch assigned',
            subtitle: 'Ask the Owner to assign you to a branch.',
            icon: Icons.store_mall_directory_outlined,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(managerDashboardProvider);
            await ref.read(managerDashboardProvider.future);
          },
          child: _DashboardContent(kpis: kpis),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Content
// ─────────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final ManagerDashboardKpis kpis;
  const _DashboardContent({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final branch = kpis.branch!;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // ─── Header ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name,
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${branch.code} · ${_formatDate(DateTime.now())}',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            StatusChip(
              label: branch.isActive ? 'Active' : 'Inactive',
              type: branch.isActive ? StatusType.success : StatusType.warning,
            ),
          ],
        ),

        // ─── Inactive branch warning ────────────────────────
        if (!branch.isActive) ...[
          const SizedBox(height: AppSpacing.sm),
          const _InactiveWarning(),
        ],

        const SizedBox(height: AppSpacing.lg),

        // ─── KPI grid ───────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.inbox_rounded,
                label: 'Waiting for pickup',
                value: '${kpis.deliveries.waitingPickup}',
                isHighlighted: kpis.deliveries.waitingPickup > 0,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.local_shipping_rounded,
                label: 'In transit',
                value: '${kpis.deliveries.inTransit}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.calendar_today_rounded,
                label: 'Deliveries today',
                value: '${kpis.deliveries.todayCount}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.check_circle_rounded,
                label: 'Delivered today',
                value: '${kpis.deliveries.deliveredToday}',
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Revenue today ──────────────────────────────────
        _SectionHeader(
          title: 'Revenue today',
          icon: Icons.payments_rounded,
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.trending_up_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _formatTsh(kpis.revenue.todayTsh),
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Team ───────────────────────────────────────────
        _SectionHeader(
          title: 'Team',
          icon: Icons.people_rounded,
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Row(label: 'Receivers', value: '${kpis.staff.receivers}'),
              _Row(label: 'Riders', value: '${kpis.staff.riders}'),
              const Divider(height: AppSpacing.lg),
              _Row(
                label: 'Total active',
                value: '${kpis.staff.totalActive}',
                isBold: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Inactive warning
// ─────────────────────────────────────────────────────────────

class _InactiveWarning extends StatelessWidget {
  const _InactiveWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Your branch is currently inactive. Contact the Owner to reactivate.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KPI tile
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
// Section header + row
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

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _Row({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: text.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
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