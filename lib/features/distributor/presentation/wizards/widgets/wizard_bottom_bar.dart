import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../widgets/widgets.dart';

/// Shared bottom bar for every wizard step.
///
/// Left = back/cancel (secondary). Right = next/submit (primary, wider).
class WizardBottomBar extends StatelessWidget {
  final String backLabel;
  final VoidCallback? onBack;
  final String nextLabel;
  final VoidCallback? onNext;
  final bool isLoading;

  const WizardBottomBar({
    super.key,
    this.backLabel = 'Back',
    required this.onBack,
    required this.nextLabel,
    required this.onNext,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: backLabel,
                  onPressed: isLoading ? null : onBack,
                  variant: AppButtonVariant.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: nextLabel,
                  onPressed: isLoading ? null : onNext,
                  isLoading: isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}