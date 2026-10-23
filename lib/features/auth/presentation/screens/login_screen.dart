import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/repositories/health_repository.dart';

/// Sign-in screen.
///
/// The email/password fields and "Sign in" button are placeholders — real
/// auth is wired in Phase 3. Until then, dev-only role-jump chips (visible
/// only when [AppConfig.isDev]) let us navigate into each dashboard for
/// routing verification.
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
      onFailure: (failure) => _showSnack(
        failure.message,
        isError: true,
      ),
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

              // ─── Brand ────────────────────────────────────────────
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

              // ─── Form ─────────────────────────────────────────────
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _onSignIn,
                child: const Text('Sign in'),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: _onSignIn,
                child: const Text('Forgot password?'),
              ),

              // ─── Dev-only helpers ─────────────────────────────────
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
                TextButton.icon(
                  onPressed: _checkingApi ? null : _onTestApi,
                  icon: _checkingApi
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: const Text('Test API connection'),
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