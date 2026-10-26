import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/routing/role_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/auth/auth_login_result.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../widgets/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthRepository _authRepo;

  bool _submitting = false;
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  // Field-level errors returned by the server on 422. Cleared on next
  // submit so stale server errors don't overlay fresh input.
  String? _emailServerError;
  String? _passwordServerError;

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepository();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Submit ───────────────────────────────────────────────
  Future<void> _onSubmit() async {
    // 1. Clear stale server errors.
    setState(() {
      _emailServerError = null;
      _passwordServerError = null;
    });

    // 2. Client-side validation.
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    // 3. Kick off the request.
    setState(() => _submitting = true);

    final result = await _authRepo.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    // 4. Handle outcome.
    result.fold(
      onSuccess: (AuthLoginResult loginResult) => _handleSuccess(loginResult),
      onFailure: (Failure failure) => _handleFailure(failure),
    );
  }

  Future<void> _handleSuccess(AuthLoginResult loginResult) async {
    // Persist tokens + update session state BEFORE navigating, so the
    // router's redirect sees the role.
    await ref.read(sessionProvider.notifier).signIn(
          user: loginResult.user,
          tokens: loginResult.tokens,
        );

    if (!mounted) return;
    context.go(RoleGuard.homeForRole(loginResult.user.role));
  }

  void _handleFailure(Failure failure) {
    // 422: field-level errors → inline under each field.
    if (failure.fieldErrors.isNotEmpty) {
      setState(() {
        _emailServerError = _firstOrNull(failure.fieldErrors['email']);
        _passwordServerError = _firstOrNull(failure.fieldErrors['password']);
        _autoValidate = AutovalidateMode.onUserInteraction;
      });
      _formKey.currentState?.validate();
      return;
    }

    // Everything else (401, 403, 429, 500, network): single red SnackBar
    // with the server's message.
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

  static String? _firstOrNull(List<String>? list) =>
      (list == null || list.isEmpty) ? null : list.first;

  // ─── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // ─── Brand ────────────────────────────────────────
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Welcome to ODS',
                textAlign: TextAlign.center,
                style: text.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppConfig.appTagline,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ─── Form ─────────────────────────────────────────
              Form(
                key: _formKey,
                autovalidateMode: _autoValidate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.mail_outline_rounded,
                      enabled: !_submitting,
                      validator: (v) =>
                          _emailServerError ?? Validators.email(v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline_rounded,
                      enabled: !_submitting,
                      validator: (v) =>
                          _passwordServerError ??
                          Validators.password(v, minLength: 1),
                      onFieldSubmitted: (_) => _onSubmit(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Sign in',
                      onPressed: _onSubmit,
                      isLoading: _submitting,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppButton(
                      label: 'Forgot password?',
                      onPressed: _submitting
                          ? null
                          : () {
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password reset is coming in Phase 15.',
                                    ),
                                  ),
                                );
                            },
                      variant: AppButtonVariant.text,
                      isFullWidth: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              Text(
                'v${AppConfig.appVersion} · ${AppConfig.environment.name}',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceSubtle,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}