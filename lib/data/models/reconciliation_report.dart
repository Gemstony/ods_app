import '../../core/utils/json_helpers.dart';

/// Summary counts from a reconciliation run.
///
/// RENAMED from `ReconciliationSummary` (Phase 11.6 fix) to avoid a
/// name collision with `ReconciliationSummary` in `finance_summary.dart`
/// (which is the finance equation breakdown, not a run summary).
class ReconciliationRunSummary {
  final int reconciledCount;
  final int driftCount;
  final int orphansCount;
  final int unchangedCount;

  const ReconciliationRunSummary({
    required this.reconciledCount,
    required this.driftCount,
    required this.orphansCount,
    required this.unchangedCount,
  });

  factory ReconciliationRunSummary.fromJson(Map<String, dynamic> json) =>
      ReconciliationRunSummary(
        reconciledCount: asInt(json['reconciled_count'] ?? 0),
        driftCount: asInt(json['drift_count'] ?? 0),
        orphansCount: asInt(json['orphans_count'] ?? 0),
        unchangedCount: asInt(json['unchanged_count'] ?? 0),
      );
}

class ReconciledItem {
  final int paymentId;
  final String reference;
  final int deliveryId;
  final String fromStatus;
  final String toStatus;
  final String providerStatus;
  final bool applied;

  const ReconciledItem({
    required this.paymentId,
    required this.reference,
    required this.deliveryId,
    required this.fromStatus,
    required this.toStatus,
    required this.providerStatus,
    required this.applied,
  });

  factory ReconciledItem.fromJson(Map<String, dynamic> json) => ReconciledItem(
        paymentId: asInt(json['payment_id']),
        reference: json['reference'] as String,
        deliveryId: asInt(json['delivery_id']),
        fromStatus: json['from_status'] as String,
        toStatus: json['to_status'] as String,
        providerStatus: json['provider_status'] as String,
        applied: json['applied'] == true,
      );
}

class ReconciliationDriftItem {
  final int paymentId;
  final String reference;
  final String localStatus;
  final String providerStatus;
  final String reason;

  const ReconciliationDriftItem({
    required this.paymentId,
    required this.reference,
    required this.localStatus,
    required this.providerStatus,
    required this.reason,
  });

  factory ReconciliationDriftItem.fromJson(Map<String, dynamic> json) =>
      ReconciliationDriftItem(
        paymentId: asInt(json['payment_id']),
        reference: json['reference'] as String,
        localStatus: json['local_status'] as String,
        providerStatus: json['provider_status'] as String,
        reason: json['reason'] as String? ?? '',
      );
}

class ReconciliationOrphanItem {
  final int paymentId;
  final String reference;
  final int deliveryId;
  final String localStatus;
  final DateTime? initiatedAt;

  const ReconciliationOrphanItem({
    required this.paymentId,
    required this.reference,
    required this.deliveryId,
    required this.localStatus,
    this.initiatedAt,
  });

  factory ReconciliationOrphanItem.fromJson(Map<String, dynamic> json) =>
      ReconciliationOrphanItem(
        paymentId: asInt(json['payment_id']),
        reference: json['reference'] as String,
        deliveryId: asInt(json['delivery_id']),
        localStatus: json['local_status'] as String,
        initiatedAt: parseDate(json['initiated_at']),
      );
}

/// Full result of one reconciliation run.
class ReconciliationReport {
  final bool dryRun;
  final String? error;
  final DateTime since;
  final DateTime runAt;
  final int localScanned;
  final int providerFetched;
  final ReconciliationRunSummary summary; // ← renamed type
  final List<ReconciledItem> reconciled;
  final List<ReconciliationDriftItem> drift;
  final List<ReconciliationOrphanItem> orphans;

  const ReconciliationReport({
    required this.dryRun,
    required this.since,
    required this.runAt,
    required this.localScanned,
    required this.providerFetched,
    required this.summary,
    required this.reconciled,
    required this.drift,
    required this.orphans,
    this.error,
  });

  factory ReconciliationReport.fromJson(Map<String, dynamic> json) {
    final rawReconciled = json['reconciled'];
    final rawDrift = json['drift'];
    final rawOrphans = json['orphans'];
    final rawSummary = json['summary'];

    return ReconciliationReport(
      dryRun: json['dry_run'] == true,
      error: json['error'] as String?,
      since: parseDate(json['since']) ?? DateTime.now(),
      runAt: parseDate(json['run_at']) ?? DateTime.now(),
      localScanned: asInt(json['local_scanned'] ?? 0),
      providerFetched: asInt(json['provider_fetched'] ?? 0),
      summary: rawSummary is Map
          ? ReconciliationRunSummary.fromJson(
              Map<String, dynamic>.from(rawSummary),
            )
          : const ReconciliationRunSummary(
              reconciledCount: 0,
              driftCount: 0,
              orphansCount: 0,
              unchangedCount: 0,
            ),
      reconciled: rawReconciled is List
          ? rawReconciled
              .whereType<Map>()
              .map((j) => ReconciledItem.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false)
          : const [],
      drift: rawDrift is List
          ? rawDrift
              .whereType<Map>()
              .map((j) =>
                  ReconciliationDriftItem.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false)
          : const [],
      orphans: rawOrphans is List
          ? rawOrphans
              .whereType<Map>()
              .map((j) =>
                  ReconciliationOrphanItem.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false)
          : const [],
    );
  }

  bool get hasIssues =>
      summary.driftCount > 0 || summary.orphansCount > 0 || error != null;
}

/// Last-run summary from `GET /owner/ledger/reconcile/last`.
class ReconciliationLastRun {
  final bool hasRun;
  final DateTime? ranAt;
  final int? actorId;
  final String? description;
  final Map<String, dynamic>? changes;

  const ReconciliationLastRun({
    required this.hasRun,
    this.ranAt,
    this.actorId,
    this.description,
    this.changes,
  });

  factory ReconciliationLastRun.fromJson(Map<String, dynamic> json) =>
      ReconciliationLastRun(
        hasRun: json['has_run'] == true,
        ranAt: parseDate(json['ran_at']),
        actorId: json['actor_id'] == null ? null : asInt(json['actor_id']),
        description: json['description'] as String?,
        changes: asMap(json['changes']),
      );
}