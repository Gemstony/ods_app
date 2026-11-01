import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/finance_summary.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_finance_providers.dart';

class OwnerFinanceTab extends ConsumerWidget {
  const OwnerFinanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(ownerFinanceProvider);

    return summaryAsync.when(
      loading: () => const LoadingView(message: 'Loading finance summary…'),
      error: (_, __) => ErrorView(
        message: 'Could not load financial summary.',
        onRetry: () => ref.invalidate(ownerFinanceProvider),
      ),
      data: (summary) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerFinanceProvider);
          await ref.read(ownerFinanceProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _RevenueSection(revenue: summary.revenue),
            const SizedBox(height: AppSpacing.lg),
            _PayablesSection(payables: summary.payables),
            const SizedBox(height: AppSpacing.lg),
            _ReconciliationSection(reconciliation: summary.reconciliation),
            const SizedBox(height: AppSpacing.lg),
            _PayoutsSection(payouts: summary.payouts),
            const SizedBox(height: AppSpacing.lg),
            _RecentPayoutsSection(payouts: summary.recentPayouts),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Revenue section
// ─────────────────────────────────────────────────────────────

class _RevenueSection extends StatelessWidget {
  final RevenueSummary revenue;
  const _RevenueSection({required this.revenue});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          title: 'Revenue',
          icon: Icons.trending_up_rounded,
          subtitle: 'Completed payments only',
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                label: 'Today',
                value: _formatTsh(revenue.todayTsh),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _KpiTile(
                label: 'This week',
                value: _formatTsh(revenue.thisWeekTsh),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                label: 'This month',
                value: _formatTsh(revenue.thisMonthTsh),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _KpiTile(
                label: 'All time',
                value: _formatTsh(revenue.allTimeTsh),
                isHighlighted: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _KpiTile({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: isHighlighted ? AppColors.primary : AppColors.onSurface,
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
// Payables section
// ─────────────────────────────────────────────────────────────

class _PayablesSection extends StatelessWidget {
  final PayablesSummary payables;
  const _PayablesSection({required this.payables});

  @override
  Widget build(BuildContext context) {
    final isOwed = payables.totalTsh > 0;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          title: 'Outstanding payables',
          icon: Icons.account_balance_rounded,
          subtitle: 'Money ODS owes right now',
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isOwed ? AppColors.warningSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isOwed ? AppColors.warning : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Total owed',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTsh(payables.totalTsh),
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isOwed
                          ? AppColors.warning
                          : AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              _Row(
                label: 'Rider earnings',
                value: _formatTsh(payables.totalRiderTsh),
                detail:
                    '(${_formatTsh(payables.riderPendingTsh)} pending · ${_formatTsh(payables.riderApprovedTsh)} approved)',
              ),
              _Row(
                label: 'Dispatcher earnings',
                value: _formatTsh(payables.totalDispatcherTsh),
                detail:
                    '(${_formatTsh(payables.dispatcherPendingTsh)} pending · ${_formatTsh(payables.dispatcherApprovedTsh)} approved)',
              ),
              _Row(
                label: 'Transport fare owed',
                value: _formatTsh(payables.transportFareOwedTsh),
                detail: '(to bus/cargo providers)',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reconciliation section
// ─────────────────────────────────────────────────────────────

class _ReconciliationSection extends StatelessWidget {
  final ReconciliationSummary reconciliation;
  const _ReconciliationSection({required this.reconciliation});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final positive = reconciliation.isPositive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          title: 'Reconciliation',
          icon: Icons.calculate_rounded,
          subtitle: 'This month · operating surplus calculation',
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
              _EquationRow(
                label: 'Revenue',
                value: _formatTsh(reconciliation.revenueThisMonthTsh),
              ),
              _EquationRow(
                label: '− Payouts',
                value: _formatTsh(reconciliation.minusPayoutsThisMonthTsh),
              ),
              _EquationRow(
                label: '− Transport paid',
                value: _formatTsh(
                    reconciliation.minusTransportPaidThisMonthTsh),
              ),
              _EquationRow(
                label: '− Expenses',
                value:
                    _formatTsh(reconciliation.minusExpensesThisMonthTsh),
              ),
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  Text(
                    'Operating surplus',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTsh(reconciliation.operatingSurplusTsh),
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: positive
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EquationRow extends StatelessWidget {
  final String label;
  final String value;

  const _EquationRow({required this.label, required this.value});

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
              ),
            ),
          ),
          Text(
            value,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Payouts summary section
// ─────────────────────────────────────────────────────────────

class _PayoutsSection extends StatelessWidget {
  final PayoutsSummary payouts;
  const _PayoutsSection({required this.payouts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          title: 'Payouts',
          icon: Icons.payments_rounded,
          subtitle: 'Money that already left ODS',
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
              _Row(
                label: 'This month',
                value: _formatTsh(payouts.thisMonthTsh),
                detail: '${payouts.thisMonthCount} payout${payouts.thisMonthCount == 1 ? '' : 's'}',
              ),
              _Row(
                label: 'Pending',
                value: _formatTsh(payouts.pendingTsh),
                detail: '${payouts.pendingCount} awaiting processing',
                isWarning: payouts.pendingCount > 0,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Recent payouts
// ─────────────────────────────────────────────────────────────

class _RecentPayoutsSection extends StatelessWidget {
  final List<RecentPayout> payouts;
  const _RecentPayoutsSection({required this.payouts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          title: 'Recent payouts',
          icon: Icons.history_rounded,
          subtitle: 'Latest 5 payout records',
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: payouts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    'No payouts recorded yet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceMuted,
                        ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < payouts.length; i++) ...[
                      _PayoutRow(payout: payouts[i]),
                      if (i < payouts.length - 1)
                        const Divider(height: AppSpacing.lg),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _PayoutRow extends StatelessWidget {
  final RecentPayout payout;
  const _PayoutRow({required this.payout});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.surface,
          child: Icon(
            _statusIcon(payout.status),
            size: 16,
            color: _statusColor(payout.status),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payout.userName,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _formatDate(payout.processedAt ?? payout.requestedAt),
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTsh(payout.amount),
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _statusLabel(payout.status),
              style: text.bodySmall?.copyWith(
                color: _statusColor(payout.status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static IconData _statusIcon(String s) => switch (s) {
        'paid' => Icons.check_circle,
        'pending' || 'processing' => Icons.schedule,
        'failed' => Icons.error_outline,
        _ => Icons.help_outline,
      };

  static Color _statusColor(String s) => switch (s) {
        'paid' => AppColors.success,
        'pending' || 'processing' => AppColors.warning,
        'failed' => AppColors.error,
        _ => AppColors.onSurfaceMuted,
      };

  static String _statusLabel(String s) => switch (s) {
        'paid' => 'Paid',
        'pending' => 'Pending',
        'processing' => 'Processing',
        'failed' => 'Failed',
        _ => s,
      };
}

// ─────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              title,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final bool isWarning;

  const _Row({
    required this.label,
    required this.value,
    this.detail,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onSurfaceSubtle,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isWarning ? AppColors.warning : AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTsh(double amount) {
  if (amount.abs() >= 1000000) {
    return 'TZS ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount.abs() >= 10000) {
    return 'TZS ${(amount / 1000).toStringAsFixed(1)}k';
  }
  return 'TZS ${amount.toStringAsFixed(0)}';
}

String _formatDate(DateTime? dt) {
  if (dt == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}