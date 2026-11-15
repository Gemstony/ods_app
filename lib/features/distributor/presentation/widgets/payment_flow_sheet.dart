import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../data/models/payment.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../widgets/widgets.dart';
import '../providers/payment_flow_providers.dart';

/// Modal bottom sheet driving one payment attempt.
///
/// Returns `true` when the payment completes successfully (parent
/// should refresh). Returns `null` on manual dismissal OR when a manual
/// payment was recorded — delivery stays `pending_payment` until the
/// Manager approves.
class PaymentFlowSheet extends ConsumerStatefulWidget {
  final Delivery delivery;

  const PaymentFlowSheet({super.key, required this.delivery});

  static Future<bool?> show(BuildContext context, Delivery delivery) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentFlowSheet(delivery: delivery),
    );
  }

  @override
  ConsumerState<PaymentFlowSheet> createState() => _PaymentFlowSheetState();
}

class _PaymentFlowSheetState extends ConsumerState<PaymentFlowSheet> {
  final _phoneController = TextEditingController();
  bool _preFilled = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (user?.phone != null && user!.phone.isNotEmpty) {
      _phoneController.text = _normalizePhone(user.phone);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  static String _normalizePhone(String raw) {
    final t = raw.trim().replaceAll(' ', '');
    if (t.startsWith('+255') && t.length == 13) return t.substring(1);
    if (t.startsWith('0') && t.length == 10) return '255${t.substring(1)}';
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentFlowProvider(widget.delivery.id));

    ref.listen<PaymentFlowState>(
      paymentFlowProvider(widget.delivery.id),
      (prev, next) {
        if (next is PaymentFlowSuccess && _preFilled == false) {
          _preFilled = true;
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        }
      },
    );

    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
                  'Pay for delivery',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.delivery.trackingId,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 20),
                _buildBody(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(PaymentFlowState state) {
    return switch (state) {
      PaymentFlowIdle() => _buildIdle(),
      PaymentFlowBusy(:final message) => _buildBusy(message),
      PaymentFlowInFlight(:final payment) => _buildInFlight(payment),
      PaymentFlowAwaitingApproval(:final payment) =>
        _buildAwaitingApproval(payment),
      PaymentFlowSuccess(:final payment) => _buildSuccess(payment),
      PaymentFlowFailed(:final payment) => _buildFailed(payment),
      PaymentFlowError(:final message) => _buildError(message),
    };
  }

  // ─── Idle ────────────────────────────────────────────────
  Widget _buildIdle() {
    final amountLabel = widget.delivery.totalAmountLabel;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Total due',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ),
              Text(
                amountLabel,
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'USSD prompt will be sent to:',
          style: text.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: const InputDecoration(
            hintText: '255712345678',
            prefixIcon: Icon(Icons.phone_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Send USSD prompt',
          icon: Icons.sms_rounded,
          onPressed: _onSubmit,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            '— or —',
            style: text.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _onManualTap,
          icon: const Icon(Icons.storefront_rounded, size: 18),
          label: const Text('Pay at branch (cash)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  void _onSubmit() {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^255\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('Enter a valid phone in 255XXXXXXXXX format.'),
        ));
      return;
    }
    ref
        .read(paymentFlowProvider(widget.delivery.id).notifier)
        .initiate(phoneNumber: phone);
  }

  Future<void> _onManualTap() async {
    final result = await showDialog<_ManualConfirmResult>(
      context: context,
      builder: (_) => _ManualConfirmDialog(
        amountLabel: widget.delivery.totalAmountLabel,
      ),
    );
    if (result == null || !mounted) return;

    ref.read(paymentFlowProvider(widget.delivery.id).notifier).initiateManual(
          method: result.method,
          notes: result.notes,
        );
  }

  // ─── Busy ────────────────────────────────────────────────
  Widget _buildBusy(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─── In-flight (ClickPesa) ───────────────────────────────
  Widget _buildInFlight(Payment payment) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.infoSurface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.sms_rounded,
                  size: 40, color: AppColors.info),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Check your phone',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                payment.ussd?.message ??
                    'Enter your PIN on the USSD prompt to confirm payment.',
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Waiting for confirmation…',
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Refresh status',
          icon: Icons.refresh_rounded,
          onPressed: () => ref
              .read(paymentFlowProvider(widget.delivery.id).notifier)
              .refreshNow(),
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Reference: ${payment.reference}',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceSubtle,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close (payment will still complete)'),
        ),
      ],
    );
  }

  // ─── Awaiting approval (manual) ──────────────────────────
  Widget _buildAwaitingApproval(Payment payment) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warningSurface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  size: 48, color: AppColors.warning),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Awaiting approval',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your ${payment.methodLabel.toLowerCase()} payment of '
                '${payment.amountLabel} has been recorded. '
                'The branch manager needs to approve it before the '
                'delivery can proceed.',
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Reference: ${payment.reference}',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceSubtle,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Check status',
          icon: Icons.refresh_rounded,
          onPressed: () => ref
              .read(paymentFlowProvider(widget.delivery.id).notifier)
              .refreshNow(),
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  // ─── Success ─────────────────────────────────────────────
  Widget _buildSuccess(Payment payment) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 64, color: AppColors.success),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Payment received',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          payment.amountLabel,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.success,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ─── Failed ──────────────────────────────────────────────
  Widget _buildFailed(Payment payment) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.cancel_rounded, size: 48, color: AppColors.error),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Payment failed',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        if (payment.failureReason != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            payment.failureReason!,
            style: text.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: () => ref
              .read(paymentFlowProvider(widget.delivery.id).notifier)
              .reset(),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  // ─── Error ───────────────────────────────────────────────
  Widget _buildError(String message) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.error_outline_rounded,
            size: 48, color: AppColors.warning),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Refresh status',
          icon: Icons.refresh_rounded,
          onPressed: () => ref
              .read(paymentFlowProvider(widget.delivery.id).notifier)
              .refreshNow(),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Manual confirm dialog
// ═══════════════════════════════════════════════════════════════

class _ManualConfirmResult {
  final String method;
  final String? notes;
  const _ManualConfirmResult({required this.method, this.notes});
}

class _ManualConfirmDialog extends StatefulWidget {
  final String amountLabel;
  const _ManualConfirmDialog({required this.amountLabel});

  @override
  State<_ManualConfirmDialog> createState() => _ManualConfirmDialogState();
}

class _ManualConfirmDialogState extends State<_ManualConfirmDialog> {
  String _method = 'cash';
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Pay at branch?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Record a manual payment of ${widget.amountLabel} for this '
              'delivery. The branch manager will approve it once they '
              'confirm receipt.',
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Method',
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Cash'),
                  selected: _method == 'cash',
                  onSelected: (_) => setState(() => _method = 'cash'),
                ),
                ChoiceChip(
                  label: const Text('Manual / other'),
                  selected: _method == 'manual',
                  onSelected: (_) => setState(() => _method = 'manual'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. paid at branch reception',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final notes = _notesController.text.trim();
            Navigator.of(context).pop(_ManualConfirmResult(
              method: _method,
              notes: notes.isEmpty ? null : notes,
            ));
          },
          child: const Text('Record'),
        ),
      ],
    );
  }
}