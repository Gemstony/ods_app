import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/manager_manual_payment.dart';
import '../../../../data/repositories/manual_payment_repository.dart';
import '../../../../widgets/widgets.dart';
import '../providers/manual_payments_provider.dart';

/// Shared approval screen used by Manager (branch-scoped) and Owner
/// (all-branches fallback).
///
/// Constructor flag `forOwner` determines which provider is watched and
/// which repository method branch is used. All UI + behaviour identical.
class ManualPaymentsScreen extends ConsumerWidget {
  final bool forOwner;
  const ManualPaymentsScreen({super.key, this.forOwner = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = forOwner
        ? ownerPendingManualPaymentsProvider
        : managerPendingManualPaymentsProvider;
    final async = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(forOwner ? 'Manual Payment Approvals' : 'Approvals'),
      ),
      body: async.when(
        loading: () => const LoadingView(message: 'Loading pending payments…'),
        error: (_, __) => ErrorView(
          message: 'Could not load pending payments.',
          onRetry: () => ref.invalidate(provider),
        ),
        data: (payments) {
          if (payments.isEmpty) {
            return const EmptyView(
              title: 'No pending approvals',
              subtitle:
                  'Manual payments waiting for approval will appear here.',
              icon: Icons.check_circle_outline_rounded,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(provider);
              await ref.read(provider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _PendingPaymentCard(
                payment: payments[i],
                forOwner: forOwner,
                onSuccess: () => ref.invalidate(provider),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Pending payment card
// ═══════════════════════════════════════════════════════════════

class _PendingPaymentCard extends ConsumerStatefulWidget {
  final ManagerManualPayment payment;
  final bool forOwner;
  final VoidCallback onSuccess;
  const _PendingPaymentCard({
    required this.payment,
    required this.forOwner,
    required this.onSuccess,
  });

  @override
  ConsumerState<_PendingPaymentCard> createState() =>
      _PendingPaymentCardState();
}

class _PendingPaymentCardState extends ConsumerState<_PendingPaymentCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = widget.payment;

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
              const Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  p.reference,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                p.amountLabel,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              _Chip(label: p.methodLabel, color: AppColors.info),
              const SizedBox(width: 6),
              _Chip(label: p.stageLabel, color: AppColors.onSurfaceMuted),
            ],
          ),
          if (p.delivery != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 14,
                  color: AppColors.onSurfaceMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p.delivery!.trackingId,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (p.initiatedBy != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: AppColors.onSurfaceMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p.initiatedBy!.name,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _onRejectTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _onApproveTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onApproveTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve payment?'),
        content: Text(
          'Confirm that you have received '
          '${widget.payment.amountLabel} in '
          '${widget.payment.methodLabel.toLowerCase()} for '
          '${widget.payment.delivery?.trackingId ?? "this delivery"}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _runAction(
      action: (repo) => repo.approve(
        paymentId: widget.payment.id,
        forOwner: widget.forOwner,
      ),
      successMessage: 'Payment approved.',
    );
  }

  Future<void> _onRejectTap() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectReasonDialog(),
    );
    if (reason == null || !mounted) return;
    await _runAction(
      action: (repo) => repo.reject(
        paymentId: widget.payment.id,
        reason: reason,
        forOwner: widget.forOwner,
      ),
      successMessage: 'Payment rejected.',
    );
  }

  Future<void> _runAction({
    required Future<dynamic> Function(ManualPaymentRepository) action,
    required String successMessage,
  }) async {
    setState(() => _busy = true);

    final repo = ref.read(manualPaymentRepositoryProvider);
    final result = await action(repo);

    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      onSuccess: (_) {
        widget.onSuccess();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(successMessage)));
      },
      onFailure: (f) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Reject reason dialog
// ═══════════════════════════════════════════════════════════════

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject payment'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Reason',
          hintText: 'e.g. cash not received at branch',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.length < 5) {
              setState(() => _error = 'At least 5 characters required.');
              return;
            }
            Navigator.of(context).pop(reason);
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}