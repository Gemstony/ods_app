import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ods_app/core/errors/failure.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/dashboard_kpis.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/dashboard_providers.dart';
import '../../../../widgets/widgets.dart';

/// The Owner's Home tab — the platform's command center.
///
/// Shows aggregated KPIs from `GET /owner/dashboard`: pending approvals,
/// active branches, today's deliveries, today's revenue, financial
/// snapshot (revenue + payables), team counts, delivery operations, and
/// open disputes.
///
/// Pull-to-refresh invalidates the provider. Loading shows a spinner,
/// error shows a retry button.
class OwnerHomeTab extends ConsumerWidget {
  const OwnerHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(ownerDashboardProvider);

    return kpisAsync.when(
      loading: () => const LoadingView(message: 'Loading dashboard…'),
      error: (error, _) => ErrorView(
        message: error is Failure
            ? error.message
            : 'Could not load dashboard. Please try again.',
        onRetry: () => ref.invalidate(ownerDashboardProvider),
      ),
      data: (kpis) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerDashboardProvider);
          await ref.read(ownerDashboardProvider.future);
        },
        child: _DashboardContent(kpis: kpis),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Content
// ─────────────────────────────────────────────────────────────────────

class _DashboardContent extends ConsumerWidget {
  final DashboardKpis kpis;
  const _DashboardContent({required this.kpis});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // ─── Welcome header ─────────────────────────────────
        Text(
          'Welcome${user?.name != null ? ', ${_firstName(user!.name)}' : ''}',
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          _formatDate(DateTime.now()),
          style: text.bodyMedium?.copyWith(
            color: AppColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ─── KPI grid ────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.pending_actions_rounded,
                label: 'Pending approvals',
                value: '${kpis.users.pendingApprovals}',
                isHighlighted: kpis.users.pendingApprovals > 0,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.store_rounded,
                label: 'Active branches',
                value: '${kpis.branches.totalActive}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.local_shipping_rounded,
                label: 'Deliveries today',
                value: '${kpis.deliveries.todayCount}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.payments_rounded,
                label: 'Revenue today',
                value: _formatTsh(kpis.revenue.todayTsh),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Financial snapshot ─────────────────────────────
        _SectionHeader(
          title: 'Financial snapshot',
          icon: Icons.account_balance_wallet_rounded,
        ),
        const SizedBox(height: AppSpacing.xs),
        _FinancialCard(revenue: kpis.revenue, payables: kpis.payables),

        const SizedBox(height: AppSpacing.xl),

        // ─── Team ───────────────────────────────────────────
        _SectionHeader(
          title: 'Team',
          icon: Icons.people_rounded,
        ),
        const SizedBox(height: AppSpacing.xs),
        _TeamCard(users: kpis.users),

        const SizedBox(height: AppSpacing.xl),

        // ─── Delivery operations ────────────────────────────
        _SectionHeader(
          title: 'Delivery operations',
          icon: Icons.local_shipping_rounded,
        ),
        const SizedBox(height: AppSpacing.xs),
        _OperationsCard(deliveries: kpis.deliveries),

        // ─── Disputes banner (only when there are any) ──────
        if (kpis.openDisputes > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          _DisputesBanner(count: kpis.openDisputes),
        ],

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }
}

// ─────────────────────────────────────────────────────────────────────
// KPI tile
// ─────────────────────────────────────────────────────────────────────

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
    final valueColor =
        isHighlighted ? AppColors.warning : AppColors.onSurface;
    final iconColor =
        isHighlighted ? AppColors.warning : AppColors.primary;

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

// ─────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────
// Financial snapshot
// ─────────────────────────────────────────────────────────────────────

class _FinancialCard extends StatelessWidget {
  final RevenueKpis revenue;
  final PayableKpis payables;

  const _FinancialCard({required this.revenue, required this.payables});

  @override
  Widget build(BuildContext context) {
    return _Card(
      children: [
        _CardRow(
          label: 'Revenue today',
          value: _formatTsh(revenue.todayTsh),
        ),
        _CardRow(
          label: 'Revenue this week',
          value: _formatTsh(revenue.thisWeekTsh),
        ),
        _CardRow(
          label: 'Revenue this month',
          value: _formatTsh(revenue.thisMonthTsh),
        ),
        const Divider(height: AppSpacing.lg),
        _CardRow(
          label: 'Pending payables',
          value: _formatTsh(payables.totalTsh),
          isWarning: payables.totalTsh > 0,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Team
// ─────────────────────────────────────────────────────────────────────

class _TeamCard extends StatelessWidget {
  final UserKpis users;
  const _TeamCard({required this.users});

  @override
  Widget build(BuildContext context) {
    return _Card(
      children: [
        _CardRow(label: 'Managers', value: '${users.managers}'),
        _CardRow(label: 'Delivery agents', value: '${users.riders}'),
        _CardRow(label: 'Receivers', value: '${users.receivers}'),
        _CardRow(label: 'Distributors', value: '${users.distributors}'),
        const Divider(height: AppSpacing.lg),
        _CardRow(
          label: 'Total active users',
          value: '${users.totalActive}',
          isBold: true,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Delivery operations
// ─────────────────────────────────────────────────────────────────────

class _OperationsCard extends StatelessWidget {
  final DeliveryKpis deliveries;
  const _OperationsCard({required this.deliveries});

  @override
  Widget build(BuildContext context) {
    return _Card(
      children: [
        _CardRow(
          label: 'Active deliveries',
          value: '${deliveries.activeCount}',
        ),
        _CardRow(
          label: 'Delivered today',
          value: '${deliveries.todayDelivered}',
        ),
        _CardRow(
          label: 'This week',
          value: '${deliveries.thisWeekCount}',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Disputes banner
// ─────────────────────────────────────────────────────────────────────

class _DisputesBanner extends StatelessWidget {
  final int count;
  const _DisputesBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '$count open ${count == 1 ? 'dispute' : 'disputes'} '
              'need${count == 1 ? 's' : ''} attention',
              style: text.bodyMedium?.copyWith(
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

// ─────────────────────────────────────────────────────────────────────
// Shared card primitives
// ─────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

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

class _CardRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;
  final bool isBold;

  const _CardRow({
    required this.label,
    required this.value,
    this.isWarning = false,
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
              color: isWarning ? AppColors.warning : AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────────────────────────────────

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