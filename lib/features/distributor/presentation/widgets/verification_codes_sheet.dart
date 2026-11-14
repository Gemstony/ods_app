import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../data/models/verification_issue_result.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';

/// Distributor-only sheet to issue (or re-issue) verification codes for
/// a delivery (Phase 12.3).
///
/// Both raw codes are displayed **once**. The Distributor is expected to
/// copy them to SMS or voice before closing. After the sheet closes, the
/// codes cannot be recovered.
class VerificationCodesSheet extends ConsumerStatefulWidget {
  final Delivery delivery;

  const VerificationCodesSheet({super.key, required this.delivery});

  static Future<void> show(BuildContext context, Delivery delivery) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerificationCodesSheet(delivery: delivery),
    );
  }

  @override
  ConsumerState<VerificationCodesSheet> createState() =>
      _VerificationCodesSheetState();
}

class _VerificationCodesSheetState
    extends ConsumerState<VerificationCodesSheet> {
  bool _loading = true;
  String? _error;
  VerificationIssueResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.issueVerificationCodes(widget.delivery.id);
    if (!mounted) return;
    result.fold(
      onSuccess: (r) => setState(() {
        _result = r;
        _loading = false;
      }),
      onFailure: (f) => setState(() {
        _error = f.message;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
                  'Verification codes',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.delivery.trackingId,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _ErrorBlock(
                    message: _error!,
                    onClose: () => Navigator.of(context).pop(),
                  )
                else if (_result != null)
                  _CodesBlock(result: _result!),
                const SizedBox(height: AppSpacing.md),
                if (!_loading && _error == null)
                  AppButton(
                    label: 'Done — I have saved the codes',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodesBlock extends StatelessWidget {
  final VerificationIssueResult result;
  const _CodesBlock({required this.result});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CodeCard(
          label: 'Distributor code',
          code: result.distributorCode,
          hint: 'Give to the Rider or Receiver at pickup.',
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.sm),
        _CodeCard(
          label: 'Recipient code',
          code: result.recipientCode,
          hint: 'Give to the recipient at delivery handover.',
          color: AppColors.info,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
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
                  result.warning ??
                      'These codes will not be shown again after you close this sheet.',
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String label;
  final IssuedCode code;
  final String hint;
  final Color color;
  const _CodeCard({
    required this.label,
    required this.code,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                code.expiryLabel,
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  code.code,
                  style: text.headlineMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code.code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(content: Text('$label copied.')),
                      );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            hint,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorBlock({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.errorSurface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Close',
          onPressed: onClose,
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}