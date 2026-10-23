import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/health_repository.dart';

class OdsApp extends StatelessWidget {
  const OdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _BootScreen(),
      ),
    );
  }
}

/// Temporary boot screen. Verifies Sub-phases 1.1–1.4 end-to-end:
/// theme, config, and the full network error pipeline.
///
/// Removed in Sub-phase 1.5 when routing takes over.
class _BootScreen extends StatefulWidget {
  const _BootScreen();

  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen> {
  final _repo = HealthRepository();
  bool _checking = false;

  Future<void> _testApiConnection() async {
    setState(() => _checking = true);
    final result = await _repo.check();
    if (!mounted) return;
    setState(() => _checking = false);

    result.fold(
      onSuccess: (data) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'API OK · env=${data['env']} · db=${data['database']}',
              ),
            ),
          );
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: AppColors.error,
            ),
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.appName)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Brand block ────────────────────────────────────
              Text(
                AppConfig.appName,
                style: text.displaySmall?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppConfig.appTagline,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ─── Config card ────────────────────────────────────
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      _KeyValue(
                        label: 'Environment',
                        value: AppConfig.environment.name,
                      ),
                      _KeyValue(
                        label: 'API base URL',
                        value: AppConfig.apiBaseUrl,
                      ),
                      _KeyValue(
                        label: 'App version',
                        value: AppConfig.appVersion,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ─── API test ───────────────────────────────────────
              Text('API connection', style: text.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Hits GET /api/v1/health and shows the mapped result. '
                'Before 1.10 it will show a network failure — that is expected '
                'and proves the error pipeline works.',
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ElevatedButton(
                onPressed: _checking ? null : _testApiConnection,
                child: _checking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Test API connection'),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ─── Chips (theme preview) ──────────────────────────
              Text('Chips', style: text.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: const [
                  Chip(label: Text('Receive')),
                  Chip(label: Text('Send')),
                  Chip(label: Text('Regional')),
                  Chip(
                    label: Text('Active'),
                    backgroundColor: AppColors.successSurface,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ─── Footer ─────────────────────────────────────────
              Text(
                'Sub-phase 1.4 ✓   ·   Routing → 1.5   ·   Role panels → 1.6',
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}