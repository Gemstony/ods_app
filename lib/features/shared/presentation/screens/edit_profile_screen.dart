import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/auth/auth_user.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../widgets/widgets.dart';

/// Self-service profile editor shared by every role's Profile tab.
///
/// Editable: name + phone. Email is shown read-only — the backend treats
/// it as immutable (changing it would require a re-verification flow).
///
/// On success the returned [AuthUser] is pushed into the session via
/// [SessionNotifier.updateUser], so every screen reflecting the user
/// (header cards, AppBar, etc.) updates without a re-login.
class EditProfileScreen extends ConsumerStatefulWidget {
  final AuthUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool _submitting = false;
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;
  final Map<String, String?> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    setState(() => _serverErrors.clear());

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _submitting = true);

    final result = await ref.read(authRepositoryProvider).updateProfile(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      onSuccess: (updated) {
        ref.read(sessionProvider.notifier).updateUser(updated);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
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
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidate,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              Text(
                'Update your name and phone number. Your email cannot be '
                'changed here — contact support if you need to update it.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Email — read-only
              AppTextField(
                controller: TextEditingController(text: widget.user.email),
                label: 'Email',
                prefixIcon: Icons.mail_outline_rounded,
                enabled: false,
              ),
              const SizedBox(height: AppSpacing.sm),

              AppTextField(
                controller: _nameController,
                label: 'Full name',
                prefixIcon: Icons.person_outline_rounded,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    _serverErrors['name'] ??
                    Validators.required(v, label: 'Your full name') ??
                    Validators.minLength(v, 2, label: 'Your name'),
              ),
              const SizedBox(height: AppSpacing.sm),

              AppTextField(
                controller: _phoneController,
                label: 'Phone',
                hint: '0712 345 678',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                enabled: !_submitting,
                textInputAction: TextInputAction.done,
                validator: (v) => _serverErrors['phone'] ?? Validators.phone(v),
                onFieldSubmitted: (_) => _onSubmit(),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppButton(
                label: 'Save changes',
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
