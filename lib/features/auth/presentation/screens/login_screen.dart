import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/repositories/health_repository.dart';
import '../../../../widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _healthRepo = HealthRepository();

  bool _checkingApi = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignIn() {
    _showSnack('Authentication is wired in Phase 3.');
  }

  Future<void> _onTestApi() async {
    setState(() => _checkingApi = true);
    final result = await _healthRepo.check();
    if (!mounted) return;
    setState(() => _checkingApi = false);

    result.fold(
      onSuccess: (data) => _showSnack(
        'API OK · env=${data['env']} · db=${data['database']}',
      ),
      onFailure: (failure) => _showSnack(failure.message, isError: true),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }

  void _goTo(String path) => context.go(path);

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

              // ─── Brand ───────────────────────────────────────────
              const Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primary,
                  child: Icon(
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

              // ─── Form ────────────────────────────────────────────
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.mail_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                obscureText: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline_rounded,
                onFieldSubmitted: (_) => _onSignIn(),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Sign in',
                onPressed: _onSignIn,
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Forgot password?',
                onPressed: _onSignIn,
                variant: AppButtonVariant.text,
                isFullWidth: false,
              ),

              // ─── Dev-only helpers ────────────────────────────────
              if (AppConfig.isDev) ...[
                const SizedBox(height: AppSpacing.xl),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Dev shortcuts',
                  textAlign: TextAlign.center,
                  style: text.labelMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ActionChip(
                      label: const Text('Owner'),
                      onPressed: () => _goTo(RouteNames.owner),
                    ),
                    ActionChip(
                      label: const Text('Manager'),
                      onPressed: () => _goTo(RouteNames.manager),
                    ),
                    ActionChip(
                      label: const Text('Distributor'),
                      onPressed: () => _goTo(RouteNames.distributor),
                    ),
                    ActionChip(
                      label: const Text('Rider'),
                      onPressed: () => _goTo(RouteNames.rider),
                    ),
                    ActionChip(
                      label: const Text('Receiver'),
                      onPressed: () => _goTo(RouteNames.receiver),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Test API connection',
                  onPressed: _checkingApi ? null : _onTestApi,
                  variant: AppButtonVariant.text,
                  icon: Icons.wifi_tethering,
                  isLoading: _checkingApi,
                  isFullWidth: false,
                ),
              ],

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