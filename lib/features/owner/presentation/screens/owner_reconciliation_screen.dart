import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/reconciliation_report.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_ledger_providers.dart';

class OwnerReconciliationScreen extends ConsumerStatefulWidget {
  const OwnerReconciliationScreen({super.key});

  @override
  ConsumerState<OwnerReconciliationScreen> createState() =>
      _OwnerReconciliationScreenState();
}

class _OwnerReconciliationScreenState
    extends ConsumerState<OwnerReconciliationScreen> {
  int _sinceDays = 7;
  bool _dryRun = false;
  ReconciliationReport? _lastReport;

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(reconciliationRunnerProvider);
    final lastAsync = ref.watch(reconciliationLastRunProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reconciliation')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          _LastRunCard(lastAsync: lastAsync),
          const SizedBox(height: AppSpacing.lg),
          _RunFormCard(
            sinceDays: _sinceDays,
            dryRun: _dryRun,
            onDaysChanged: (d) => setState(() => _sinceDays = d),
            onDryRunChanged: (v) => setState(() => _dryRun = v),
            onRun: running.isLoading ? null : _run,
          ),
          if (running.isLoading) ...[
            const SizedBox(height: AppSpacing.lg),
            const Center(child: CircularProgressIndicator()),
          ],
          if (running.hasError) ...[
            const SizedBox(height: AppSpacing.lg),
            _ErrorCard(error: running.error.toString()),
          ],
          if (_lastReport != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _ReportCard(report: _lastReport!),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _run() async {
    final report = await ref
        .read(reconciliationRunnerProvider.notifier)
        .run(
          since: DateTime.now().subtract(Duration(days: _sinceDays)),
          dryRun: _dryRun,
        );
    if (mounted && report != null) {
      setState(() => _lastReport = report);
    }
  }
}

class _LastRunCard extends StatelessWidget {
  final AsyncValue<ReconciliationLastRun> lastAsync;
  const _LastRunCard({required this.lastAsync});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('Last run',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          lastAsync.when(
            loading: () => const Text('Loading…'),
            error: (_, __) => Text(
              'Could not load last run.',
              style: text.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
            ),
            data: (last) {
              if (!last.hasRun) {
                return Text(
                  'No reconciliation has run yet.',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (last.ranAt != null)
                    Text(
                      'Ran ${_format(last.ranAt!)}',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  if (last.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      last.description!,
                      style: text.bodySmall,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _format(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _RunFormCard extends StatelessWidget {
  final int sinceDays;
  final bool dryRun;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<bool> onDryRunChanged;
  final VoidCallback? onRun;

  const _RunFormCard({
    required this.sinceDays,
    required this.dryRun,
    required this.onDaysChanged,
    required this.onDryRunChanged,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_rounded,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: AppSpacing.xs),
              Text('Run reconciliation',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int>(
            value: sinceDays,
            decoration: const InputDecoration(
              labelText: 'Look back',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Last 24 hours')),
              DropdownMenuItem(value: 7, child: Text('Last 7 days')),
              DropdownMenuItem(value: 30, child: Text('Last 30 days')),
            ],
            onChanged: (v) {
              if (v != null) onDaysChanged(v);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Dry run', style: text.bodyMedium),
            subtitle: Text(
              'Report only — do not apply changes.',
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
            value: dryRun,
            onChanged: onDryRunChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: dryRun ? 'Run (dry run)' : 'Run reconciliation',
            icon: Icons.play_arrow_rounded,
            onPressed: onRun,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReconciliationReport report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                report.dryRun
                    ? Icons.visibility_rounded
                    : Icons.check_circle_rounded,
                size: 16,
                color: report.dryRun
                    ? AppColors.warning
                    : AppColors.success,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                report.dryRun ? 'Dry run result' : 'Result',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (report.error != null)
            Text(
              report.error!,
              style: text.bodySmall?.copyWith(color: AppColors.error),
            )
          else ...[
            _row('Local scanned', '${report.localScanned}'),
            _row('Provider fetched', '${report.providerFetched}'),
            _row('Reconciled', '${report.summary.reconciledCount}',
                color: report.summary.reconciledCount > 0
                    ? AppColors.success
                    : null),
            _row('Drift (needs attention)', '${report.summary.driftCount}',
                color: report.summary.driftCount > 0
                    ? AppColors.warning
                    : null),
            _row('Orphans', '${report.summary.orphansCount}',
                color: report.summary.orphansCount > 0
                    ? AppColors.warning
                    : null),
            _row('Unchanged', '${report.summary.unchangedCount}'),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}