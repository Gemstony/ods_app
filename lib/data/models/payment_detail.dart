import '../../core/utils/json_helpers.dart';
import 'ledger_entries.dart';
import 'payment.dart';

/// A payment transaction (append-only log row).
class PaymentTransactionEntry {
  final int id;
  final String type; // initiate / callback / verify / refund
  final String provider;
  final String? providerReference;
  final String status;
  final String? errorMessage;
  final DateTime? attemptedAt;
  final Map<String, dynamic>? requestPayload;
  final Map<String, dynamic>? responsePayload;

  const PaymentTransactionEntry({
    required this.id,
    required this.type,
    required this.provider,
    required this.status,
    this.providerReference,
    this.errorMessage,
    this.attemptedAt,
    this.requestPayload,
    this.responsePayload,
  });

  factory PaymentTransactionEntry.fromJson(Map<String, dynamic> json) =>
      PaymentTransactionEntry(
        id: asInt(json['id']),
        type: json['type'] as String,
        provider: json['provider'] as String? ?? 'clickpesa',
        providerReference: json['provider_reference'] as String?,
        status: json['status'] as String,
        errorMessage: json['error_message'] as String?,
        attemptedAt: parseDate(json['attempted_at']),
        requestPayload: asMap(json['request_payload']),
        responsePayload: asMap(json['response_payload']),
      );
}

/// A stored webhook callback.
class ClickPesaCallbackEntry {
  final int id;
  final String? providerEventId;
  final String? eventType;
  final bool signatureValid;
  final DateTime? receivedAt;
  final DateTime? processedAt;
  final String? processingError;
  final Map<String, dynamic>? payload;

  const ClickPesaCallbackEntry({
    required this.id,
    required this.signatureValid,
    this.providerEventId,
    this.eventType,
    this.receivedAt,
    this.processedAt,
    this.processingError,
    this.payload,
  });

  factory ClickPesaCallbackEntry.fromJson(Map<String, dynamic> json) =>
      ClickPesaCallbackEntry(
        id: asInt(json['id']),
        providerEventId: json['provider_event_id'] as String?,
        eventType: json['event_type'] as String?,
        signatureValid: json['signature_valid'] == true,
        receivedAt: parseDate(json['received_at']),
        processedAt: parseDate(json['processed_at']),
        processingError: json['processing_error'] as String?,
        payload: asMap(json['payload']),
      );
}

/// One ClickPesa API call (audit trail).
class ClickPesaApiLogEntry {
  final int id;
  final String correlationId;
  final String method;
  final String endpoint;
  final int? responseStatus;
  final int durationMs;
  final String? errorMessage;
  final String triggeredBy;
  final Map<String, dynamic>? requestBody;
  final Map<String, dynamic>? responseBody;
  final DateTime? createdAt;

  const ClickPesaApiLogEntry({
    required this.id,
    required this.correlationId,
    required this.method,
    required this.endpoint,
    required this.durationMs,
    required this.triggeredBy,
    this.responseStatus,
    this.errorMessage,
    this.requestBody,
    this.responseBody,
    this.createdAt,
  });

  factory ClickPesaApiLogEntry.fromJson(Map<String, dynamic> json) =>
      ClickPesaApiLogEntry(
        id: asInt(json['id']),
        correlationId: json['correlation_id'] as String? ?? '',
        method: json['method'] as String,
        endpoint: json['endpoint'] as String,
        responseStatus: json['response_status'] == null
            ? null
            : asInt(json['response_status']),
        durationMs: asInt(json['duration_ms'] ?? 0),
        errorMessage: json['error_message'] as String?,
        triggeredBy: json['triggered_by'] as String? ?? 'system',
        requestBody: asMap(json['request_body']),
        responseBody: asMap(json['response_body']),
        createdAt: parseDate(json['created_at']),
      );
}

/// Full payment detail — includes all three audit trails.
class PaymentDetail {
  final OwnerPaymentEntry entry;
  final List<PaymentTransactionEntry> transactions;
  final List<ClickPesaCallbackEntry> callbacks;
  final List<ClickPesaApiLogEntry> apiLogs;

  const PaymentDetail({
    required this.entry,
    required this.transactions,
    required this.callbacks,
    required this.apiLogs,
  });

  Payment get payment => entry.payment;

  factory PaymentDetail.fromJson(Map<String, dynamic> json) {
    final rawTx = json['transactions'];
    final rawCallbacks = json['callbacks'];
    final rawLogs = json['clickpesa_api_logs'];

    return PaymentDetail(
      entry: OwnerPaymentEntry.fromJson(json),
      transactions: rawTx is List
          ? rawTx
              .whereType<Map>()
              .map((j) =>
                  PaymentTransactionEntry.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false)
          : const [],
      callbacks: rawCallbacks is List
          ? rawCallbacks
              .whereType<Map>()
              .map((j) =>
                  ClickPesaCallbackEntry.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false)
          : const [],
      apiLogs: rawLogs is List
          ? rawLogs
              .whereType<Map>()
              .map((j) =>
                  ClickPesaApiLogEntry.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false)
          : const [],
    );
  }
}