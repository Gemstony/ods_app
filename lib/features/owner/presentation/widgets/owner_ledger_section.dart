import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/owner_ledger_providers.dart';
import '../screens/owner_earnings_screen.dart';
import '../screens/owner_payments_screen.dart';
import '../screens/owner_payouts_screen.dart';
import '../screens/owner_reconciliation_screen.dart';

/// Ledger hub shown at the bottom of the Owner Finance tab.
///
/// Three tap cards → dedicated list screens. One reconciliation status
/// tile → opens the reconciliation screen where Owner can run it.
class OwnerLedgerSection extends ConsumerWidget {
  const OwnerLedgerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: Icons.menu_book_rounded,
          title: 'Ledger',
        ),
        const SizedBox(height: AppSpacing.xs),
        _LedgerTapCard(
          icon: Icons.payments_rounded,
          color: AppColors.primary,
          title: 'Payments',
          subtitle: 'All payment attempts',
          provider: ownerPaymentsProvider,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const OwnerPaymentsScreen(),
          )),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LedgerTapCard(
          icon: Icons.attach_money_rounded,
          color: AppColors.accent,
          title: 'Earnings',
          subtitle: 'Rider & dispatcher compensation',
          provider: ownerEarningsProvider,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const OwnerEarningsScreen(),
          )),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LedgerTapCard(
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.info,
          title: 'Payout batches',
          subtitle: 'Payments out to riders',
          provider: ownerPayoutsProvider,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const OwnerPayoutsScreen(),
          )),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SectionHeader(
          icon: Icons.sync_rounded,
          title: 'Payment Reconciliation',
        ),
        const SizedBox(height: AppSpacing.xs),
        _ReconciliationTile(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const OwnerReconciliationScreen(),
          )),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

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
          ),
        ),
      ],
    );
  }
}

class _LedgerTapCard<T> extends ConsumerWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final FutureProvider<List<T>> provider;
  final VoidCallback onTap;

  const _LedgerTapCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  async.when(
                    loading: () => Text(
                      'Loading…',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                    error: (_, __) => Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                    data: (items) => Text(
                      '${items.length} ${items.length == 1 ? 'entry' : 'entries'}',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReconciliationTile extends ConsumerWidget {
  final VoidCallback onTap;
  const _ReconciliationTile({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reconciliationLastRunProvider);
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.sync_rounded,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Run reconciliation',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  async.when(
                    loading: () => Text(
                      'Loading…',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                    error: (_, __) => Text(
                      'Reconcile local vs ClickPesa',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                    data: (last) {
                      if (!last.hasRun) {
                        return Text(
                          'Never run',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }
                      final ranAt = last.ranAt;
                      return Text(
                        'Last run ${ranAt == null ? '' : _relative(ranAt)}',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceMuted,
            ),
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
