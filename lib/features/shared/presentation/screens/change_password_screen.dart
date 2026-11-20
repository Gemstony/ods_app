import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../widgets/widgets.dart';

/// Self-service password change shared by every role's Profile tab.
///
/// Requires the current password plus a new password + confirmation.
/// The session stays valid after a successful change — the access-token
/// interceptor transparently rotates tokens on the next call.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _submitting = false;
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;
  final Map<String, String?> _serverErrors = {};

  @override
  void dispose() {
    _currentController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    setState(() => _serverErrors.clear());

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _submitting = true);

    final result = await ref.read(authRepositoryProvider).changePassword(
          currentPassword: _currentController.text,
          password: _passwordController.text,
          passwordConfirmation: _passwordConfirmController.text,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      onSuccess: (_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully.')),
        );
      },
      onFailure: _handleFailure,
    );
  }

  void _handleFailure(Failure failure) {
    if (failure.fieldErrors.isNotEmpty) {
      setState(() {
        for (final e in failure.fieldErrors.entries) {
          _serverErrors[e.key] = e.value.isEmpty ? null : e.value.first;
        }
        _autoValidate = AutovalidateMode.onUserInteraction;
      });
      _formKey.currentState?.validate();
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.error,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidate,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              AppTextField(
                controller: _currentController,
                label: 'Current password',
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    _serverErrors['current_password'] ??
                    Validators.required(v, label: 'Current password'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _passwordController,
                label: 'New password',
                hint: 'At least 8 characters',
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    _serverErrors['password'] ??
                    Validators.password(v, minLength: 8),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _passwordConfirmController,
                label: 'Confirm new password',
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                enabled: !_submitting,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    Validators.confirmPassword(v, _passwordController.text),
                onFieldSubmitted: (_) => _onSubmit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Change password',
                onPressed: _onSubmit,
                isLoading: _submitting,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
