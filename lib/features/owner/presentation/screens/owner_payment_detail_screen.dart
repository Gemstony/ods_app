import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/payment_detail.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_ledger_providers.dart';

class OwnerPaymentDetailScreen extends ConsumerWidget {
  final int paymentId;
  const OwnerPaymentDetailScreen({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerPaymentDetailProvider(paymentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Detail')),
      body: async.when(
        loading: () => const LoadingView(message: 'Loading…'),
        error: (_, __) => ErrorView(
          message: 'Could not load payment.',
          onRetry: () => ref.invalidate(ownerPaymentDetailProvider(paymentId)),
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ownerPaymentDetailProvider(paymentId));
            await ref.read(ownerPaymentDetailProvider(paymentId).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _HeaderCard(detail: detail),
              const SizedBox(height: AppSpacing.lg),
              if (detail.entry.delivery != null) ...[
                _DeliveryCard(detail: detail),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (detail.transactions.isNotEmpty) ...[
                _TransactionsCard(entries: detail.transactions),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (detail.callbacks.isNotEmpty) ...[
                _CallbacksCard(entries: detail.callbacks),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (detail.apiLogs.isNotEmpty) ...[
                _ApiLogsCard(entries: detail.apiLogs),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final PaymentDetail detail;
  const _HeaderCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final p = detail.payment;
    final text = Theme.of(context).textTheme;
    return _Card(children: [
      Row(
        children: [
          Expanded(
            child: Text(
              p.reference,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Text(
            p.statusLabel,
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      _kv(context, 'Amount', p.amountLabel),
      _kv(context, 'Stage', p.stageLabel),
      _kv(context, 'Method', p.methodLabel),
      if (p.providerReference != null)
        _kv(context, 'Provider ref', p.providerReference!),
      if (p.failureReason != null)
        _kv(context, 'Failure', p.failureReason!, danger: true),
      if (detail.entry.initiator != null)
        _kv(context, 'Initiated by', detail.entry.initiator!.name),
      _kv(
        context,
        'Created',
        _formatDate(p.createdAt ?? p.initiatedAt),
      ),
      if (p.paidAt != null)
        _kv(context, 'Paid at', _formatDate(p.paidAt!)),
      if (p.failedAt != null)
        _kv(context, 'Failed at', _formatDate(p.failedAt!)),
    ]);
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DeliveryCard extends StatelessWidget {
  final PaymentDetail detail;
  const _DeliveryCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final d = detail.entry.delivery!;
    return _Card(children: [
      _title(context, Icons.local_shipping_rounded, 'Delivery'),
      const SizedBox(height: AppSpacing.sm),
      _kv(context, 'Tracking', d.trackingId),
      _kv(context, 'Status', d.status),
      if (d.serviceType != null) _kv(context, 'Service', d.serviceType!),
      if (d.totalAmount != null)
        _kv(context, 'Total', 'TZS ${d.totalAmount!.toStringAsFixed(0)}'),
    ]);
  }
}

class _TransactionsCard extends StatelessWidget {
  final List<PaymentTransactionEntry> entries;
  const _TransactionsCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _Card(children: [
      _title(context, Icons.history_rounded, 'Transactions (${entries.length})'),
      const SizedBox(height: AppSpacing.xs),
      for (final e in entries) ...[
        _TxRow(entry: e),
        const SizedBox(height: AppSpacing.xs),
      ],
    ]);
  }
}

class _TxRow extends StatelessWidget {
  final PaymentTransactionEntry entry;
  const _TxRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.type.toUpperCase(),
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                entry.status,
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: entry.status == 'success'
                      ? AppColors.success
                      : entry.status == 'error'
                          ? AppColors.error
                          : AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
          if (entry.attemptedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              _shortDate(entry.attemptedAt!),
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceSubtle,
              ),
            ),
          ],
          if (entry.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              entry.errorMessage!,
              style: text.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  static String _shortDate(DateTime dt) =>
      '${dt.day}/${dt.month} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _CallbacksCard extends StatelessWidget {
  final List<ClickPesaCallbackEntry> entries;
  const _CallbacksCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _Card(children: [
      _title(context, Icons.webhook_rounded, 'Webhooks (${entries.length})'),
      const SizedBox(height: AppSpacing.xs),
      for (final c in entries) ...[
        _CallbackRow(entry: c),
        const SizedBox(height: AppSpacing.xs),
      ],
    ]);
  }
}

class _CallbackRow extends StatelessWidget {
  final ClickPesaCallbackEntry entry;
  const _CallbackRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: entry.signatureValid
            ? AppColors.successSurface
            : AppColors.errorSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                entry.signatureValid
                    ? Icons.verified_rounded
                    : Icons.gpp_bad_rounded,
                size: 14,
                color: entry.signatureValid
                    ? AppColors.success
                    : AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                entry.eventType ?? 'unknown',
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (entry.processedAt != null)
                Text(
                  _shortDate(entry.processedAt!),
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceSubtle,
                  ),
                ),
            ],
          ),
          if (entry.processingError != null) ...[
            const SizedBox(height: 4),
            Text(
              entry.processingError!,
              style: text.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  static String _shortDate(DateTime dt) =>
      '${dt.day}/${dt.month} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _ApiLogsCard extends StatelessWidget {
  final List<ClickPesaApiLogEntry> entries;
  const _ApiLogsCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _Card(children: [
      _title(context, Icons.api_rounded, 'ClickPesa API Calls (${entries.length})'),
      const SizedBox(height: AppSpacing.xs),
      for (final log in entries) ...[
        _ApiLogRow(entry: log),
        const SizedBox(height: AppSpacing.xs),
      ],
    ]);
  }
}

class _ApiLogRow extends StatelessWidget {
  final ClickPesaApiLogEntry entry;
  const _ApiLogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ok = entry.responseStatus != null &&
        entry.responseStatus! >= 200 &&
        entry.responseStatus! < 300;
    final color = entry.responseStatus == null
        ? AppColors.warning
        : ok
            ? AppColors.success
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.method,
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.endpoint,
                  style: text.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                entry.responseStatus?.toString() ?? 'network',
                style: text.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.durationMs}ms',
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceSubtle,
                ),
              ),
              const Spacer(),
              Text(
                entry.triggeredBy,
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceSubtle,
                ),
              ),
            ],
          ),
          if (entry.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              entry.errorMessage!,
              style: text.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared helpers ────────────────────────────────────────

Widget _title(BuildContext context, IconData icon, String text) {
  final t = Theme.of(context).textTheme;
  return Row(
    children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: AppSpacing.xs),
      Text(
        text,
        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

Widget _kv(BuildContext context, String label, String value,
    {bool danger = false}) {
  final text = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
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
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: danger ? AppColors.error : AppColors.onSurface,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}