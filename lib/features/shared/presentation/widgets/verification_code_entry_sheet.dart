import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../widgets/widgets.dart';

/// Reusable code-entry sheet used by Rider (pickup / deliver) and
/// Receiver (release) when the backend gate is armed (Phase 12.3).
///
/// The caller detects a `422 "verification code is required"` from the
/// initial attempt and opens this sheet with an `onSubmit` callback
/// that retries the same endpoint WITH the code. The sheet stays open
/// on wrong-code / locked-out / expired outcomes and pops with the
/// updated [Delivery] on success.
class VerificationCodeEntrySheet extends StatefulWidget {
  final Delivery delivery;
  final String codeType; // 'distributor' | 'recipient'
  final String actionLabel; // 'pickup', 'deliver', 'release'
  final Future<ApiResult<Delivery>> Function(String code) onSubmit;

  const VerificationCodeEntrySheet({
    super.key,
    required this.delivery,
    required this.codeType,
    required this.actionLabel,
    required this.onSubmit,
  });

  static Future<Delivery?> show(
    BuildContext context, {
    required Delivery delivery,
    required String codeType,
    required String actionLabel,
    required Future<ApiResult<Delivery>> Function(String code) onSubmit,
  }) {
    return showModalBottomSheet<Delivery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => VerificationCodeEntrySheet(
        delivery: delivery,
        codeType: codeType,
        actionLabel: actionLabel,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<VerificationCodeEntrySheet> createState() =>
      _VerificationCodeEntrySheetState();
}

class _VerificationCodeEntrySheetState
    extends State<VerificationCodeEntrySheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;
  bool _terminal = false; // true when locked out / expired — no more retries

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                  'Verification code required',
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
                Text(
                  'Enter the 6-digit ${_codeTypeLabel()} code to '
                  '${widget.actionLabel} this delivery.',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                    fontFamily: 'monospace',
                  ),
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  enabled: !_submitting && !_terminal,
                  onChanged: (v) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                    if (v.length == 6) _submit();
                  },
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 12,
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (!_terminal) ...[
                  AppButton(
                    label: _submitting ? 'Verifying…' : 'Verify',
                    icon: _submitting
                        ? null
                        : Icons.verified_user_rounded,
                    onPressed: _submitting ||
                            _controller.text.length != 6
                        ? null
                        : _submit,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(_terminal ? 'Close' : 'Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _codeTypeLabel() {
    return widget.codeType == 'recipient' ? 'recipient' : 'distributor';
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 6) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final result = await widget.onSubmit(code);
    if (!mounted) return;

    result.fold(
      onSuccess: (delivery) {
        setState(() => _submitting = false);
        Navigator.of(context).pop(delivery);
      },
      onFailure: (failure) {
        final message = failure.message.toLowerCase();
        final isTerminal =
            message.contains('too many') || message.contains('expired');
        setState(() {
          _submitting = false;
          _errorMessage = failure.message;
          _terminal = isTerminal;
          if (!isTerminal) {
            _controller.clear();
          }
        });
      },
    );
  }
}