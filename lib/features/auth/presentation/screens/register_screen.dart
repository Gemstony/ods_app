import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/auth/auth_user.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../widgets/widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _distributorIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  late final AuthRepository _authRepo;

  bool _submitting = false;
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  // Server-driven field errors. Cleared on next submit.
  final Map<String, String?> _serverFieldErrors = {};

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepository();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _distributorIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  // ─── Submit ───────────────────────────────────────────────
  Future<void> _onSubmit() async {
    setState(() {
      _serverFieldErrors.clear();
    });

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _submitting = true);

    final result = await _authRepo.registerDistributor(
      name: _nameController.text.trim(),
      distributorId: _distributorIdController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      passwordConfirmation: _passwordConfirmController.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      onSuccess: (AuthUser user) => _onSuccess(user),
      onFailure: (Failure failure) => _onFailure(failure),
    );
  }

  Future<void> _onSuccess(AuthUser user) async {
    // The user is `pending` — they cannot log in yet. Show a dialog with
    // a clear message and a "Back to sign in" button.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_outline,
          color: AppColors.success,
          size: 48,
        ),
        title: const Text('Account created'),
        content: const Text(
          'Your distributor account has been created and is pending '
          'approval. You will be able to sign in once an administrator '
          'approves your account.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (mounted) context.go(RouteNames.login);
            },
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  void _onFailure(Failure failure) {
    if (failure.fieldErrors.isNotEmpty) {
      setState(() {
        for (final entry in failure.fieldErrors.entries) {
          _serverFieldErrors[entry.key] =
              entry.value.isEmpty ? null : entry.value.first;
        }
        _autoValidate = AutovalidateMode.onUserInteraction;
      });
      _formKey.currentState?.validate();
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // ─── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => context.go(RouteNames.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Distributor registration',
                textAlign: TextAlign.center,
                style: text.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Create your ODS account. An administrator will review and '
                'approve it before you can sign in.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Form(
                key: _formKey,
                autovalidateMode: _autoValidate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _nameController,
                      label: 'Full name',
                      hint: 'As it appears on your NeoLife account',
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.person_outline_rounded,
                      enabled: !_submitting,
                      validator: (v) =>
                          _serverFieldErrors['name'] ??
                          Validators.required(v, label: 'Your full name') ??
                          Validators.minLength(v, 2, label: 'Your name'),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    AppTextField(
                      controller: _distributorIdController,
                      label: 'Distributor ID',
                      hint: 'Your NeoLife distributor ID',
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.badge_outlined,
                      enabled: !_submitting,
                      validator: (v) =>
                          _serverFieldErrors['distributor_id'] ??
                          Validators.required(v, label: 'Distributor ID') ??
                          Validators.minLength(
                            v,
                            3,
                            label: 'Distributor ID',
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    AppTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.mail_outline_rounded,
                      enabled: !_submitting,
                      validator: (v) =>
                          _serverFieldErrors['email'] ?? Validators.email(v),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone',
                      hint: '0712 345 678',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.phone_outlined,
                      enabled: !_submitting,
                      validator: (v) =>
                          _serverFieldErrors['phone'] ?? Validators.phone(v),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'At least 8 characters',
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.lock_outline_rounded,
                      enabled: !_submitting,
                      validator: (v) =>
                          _serverFieldErrors['password'] ??
                          Validators.password(v, minLength: 8),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    AppTextField(
                      controller: _passwordConfirmController,
                      label: 'Confirm password',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline_rounded,
                      enabled: !_submitting,
                      validator: (v) =>
                          Validators.confirmPassword(v, _passwordController.text),
                      onFieldSubmitted: (_) => _onSubmit(),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppButton(
                      label: 'Create account',
                      onPressed: _onSubmit,
                      isLoading: _submitting,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => context.go(RouteNames.login),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}