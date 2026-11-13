import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/finance_summary.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_finance_providers.dart';
import '../widgets/owner_ledger_section.dart';

/// The Owner's Finance tab.
///
/// Six summary sections (revenue / payables / payouts / costs /
/// reconciliation / recent payouts) plus the Phase 11.6 ledger hub.
class OwnerFinanceTab extends ConsumerWidget {
  const OwnerFinanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerFinanceProvider);

    return async.when(
      loading: () => const LoadingView(message: 'Loading finance summary…'),
      error: (_, __) => ErrorView(
        message: 'Could not load finance summary.',
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
            _RevenueCard(summary: summary),
            const SizedBox(height: AppSpacing.lg),
            _PayablesCard(summary: summary),
            const SizedBox(height: AppSpacing.lg),
            _PayoutsCard(summary: summary),
            const SizedBox(height: AppSpacing.lg),
            _CostsCard(summary: summary),
            const SizedBox(height: AppSpacing.lg),
            _ReconciliationCard(summary: summary),
            const SizedBox(height: AppSpacing.lg),
            _RecentPayoutsCard(summary: summary),
            const SizedBox(height: AppSpacing.lg),
            const OwnerLedgerSection(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ─── Revenue ────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  final FinanceSummary summary;
  const _RevenueCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Revenue',
      icon: Icons.trending_up_rounded,
      children: [
        _kv(context, 'Today', _tsh(summary.revenue.todayTsh)),
        _kv(context, 'This week', _tsh(summary.revenue.thisWeekTsh)),
        _kv(context, 'This month', _tsh(summary.revenue.thisMonthTsh)),
        _kv(context, 'All time', _tsh(summary.revenue.allTimeTsh)),
      ],
    );
  }
}

// ─── Payables ───────────────────────────────────────────────

class _PayablesCard extends StatelessWidget {
  final FinanceSummary summary;
  const _PayablesCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = summary.payables;

    return _Card(
      title: 'Outstanding payables',
      icon: Icons.receipt_long_rounded,
      children: [
        // Prominent total chip
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.warningSurface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              Text(
                'Total owed',
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                _tsh(p.totalTsh),
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Subsection(
          label: 'Rider earnings',
          rows: [
            _kv(context, 'Pending', _tsh(p.riderPendingTsh)),
            _kv(context, 'Approved', _tsh(p.riderApprovedTsh)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _Subsection(
          label: 'Dispatcher earnings',
          rows: [
            _kv(context, 'Pending', _tsh(p.dispatcherPendingTsh)),
            _kv(context, 'Approved', _tsh(p.dispatcherApprovedTsh)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _kv(context, 'Transport fare owed', _tsh(p.transportFareOwedTsh)),
      ],
    );
  }
}

class _Subsection extends StatelessWidget {
  final String label;
  final List<Widget> rows;
  const _Subsection({required this.label, required this.rows});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        ...rows,
      ],
    );
  }
}

// ─── Payouts ────────────────────────────────────────────────

class _PayoutsCard extends StatelessWidget {
  final FinanceSummary summary;
  const _PayoutsCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final p = summary.payouts;
    return _Card(
      title: 'Payouts',
      icon: Icons.account_balance_wallet_rounded,
      children: [
        _kv(
          context,
          'This month',
          '${p.thisMonthCount} · ${_tsh(p.thisMonthTsh)}',
        ),
        _kv(
          context,
          'Pending',
          '${p.pendingCount} · ${_tsh(p.pendingTsh)}',
        ),
      ],
    );
  }
}

// ─── Costs ──────────────────────────────────────────────────

class _CostsCard extends StatelessWidget {
  final FinanceSummary summary;
  const _CostsCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Costs',
      icon: Icons.money_off_rounded,
      children: [
        _kv(
          context,
          'Transport paid',
          _tsh(summary.transportPaid.thisMonthTsh),
        ),
        _kv(
          context,
          'Expenses (month)',
          _tsh(summary.expenses.thisMonthTsh),
        ),
        _kv(
          context,
          'Expenses (total)',
          _tsh(summary.expenses.allTimeTsh),
        ),
      ],
    );
  }
}

// ─── Reconciliation ─────────────────────────────────────────

class _ReconciliationCard extends StatelessWidget {
  final FinanceSummary summary;
  const _ReconciliationCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final r = summary.reconciliation;
    return _Card(
      title: 'Reconciliation',
      icon: Icons.balance_rounded,
      children: [
        _kv(context, 'Revenue', _tsh(r.revenueThisMonthTsh)),
        // U+2212 MINUS SIGN (not ASCII hyphen). Matches the test.
        _kv(context, '\u2212 Payouts', _tsh(r.minusPayoutsThisMonthTsh)),
        _kv(
          context,
          '\u2212 Transport paid',
          _tsh(r.minusTransportPaidThisMonthTsh),
        ),
        _kv(context, '\u2212 Expenses', _tsh(r.minusExpensesThisMonthTsh)),
        const Divider(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Operating surplus',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text(
              _tsh(r.operatingSurplusTsh),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: r.isPositive
                        ? AppColors.success
                        : AppColors.error,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Recent payouts ─────────────────────────────────────────

class _RecentPayoutsCard extends StatelessWidget {
  final FinanceSummary summary;
  const _RecentPayoutsCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Card(
      title: 'Recent payouts',
      icon: Icons.history_rounded,
      children: [
        if (summary.recentPayouts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              'No payouts recorded yet.',
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          for (final p in summary.recentPayouts) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.userName,
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusBadge(status: p.status),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${p.currency} ${p.amount.toStringAsFixed(0)}',
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = status.isEmpty
        ? 'Unknown'
        : status[0].toUpperCase() + status.substring(1);
    final (fg, bg) = switch (status) {
      'paid' => (AppColors.success, AppColors.successSurface),
      'pending' || 'processing' => (AppColors.warning, AppColors.warningSurface),
      'failed' || 'cancelled' => (AppColors.error, AppColors.errorSurface),
      _ => (AppColors.onSurfaceMuted, AppColors.surface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ─── Shared ─────────────────────────────────────────────────

Widget _kv(BuildContext context, String label, String value) {
  final text = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ),
        Text(
          value,
          style: text.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Short TZS formatter.
///   5000    → TZS 5.0k
///   100000  → TZS 100.0k
///   532000  → TZS 532.0k
///   5000000 → TZS 5.0M
String _tsh(double amount) {
  final abs = amount.abs();
  if (abs >= 1000000) {
    return 'TZS ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (abs >= 1000) {
    return 'TZS ${(amount / 1000).toStringAsFixed(1)}k';
  }
  return 'TZS ${amount.toStringAsFixed(0)}';
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Card({
    required this.title,
    required this.icon,
    required this.children,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}