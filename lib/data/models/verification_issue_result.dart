import '../../core/utils/json_helpers.dart';

/// Response shape of `POST /distributor/deliveries/{id}/verification/issue`.
///
/// Both raw codes are included here **once** — the backend returns them
/// exactly this once and never again. The app must display / copy them
/// before closing the sheet.
class VerificationIssueResult {
  final int deliveryId;
  final String trackingId;
  final IssuedCode distributorCode;
  final IssuedCode recipientCode;
  final String? warning;

  const VerificationIssueResult({
    required this.deliveryId,
    required this.trackingId,
    required this.distributorCode,
    required this.recipientCode,
    this.warning,
  });

  factory VerificationIssueResult.fromJson(Map<String, dynamic> json) {
    final rawCodes = json['codes'];
    final codes = rawCodes is Map<String, dynamic>
        ? rawCodes
        : <String, dynamic>{};

    return VerificationIssueResult(
      deliveryId: asInt(json['delivery_id']),
      trackingId: (json['tracking_id'] as String?) ?? '',
      distributorCode: IssuedCode.fromJson(
        asMap(codes['distributor']) ?? const {},
      ),
      recipientCode: IssuedCode.fromJson(
        asMap(codes['recipient']) ?? const {},
      ),
      warning: json['warning'] as String?,
    );
  }
}

/// One issued code with its expiry timestamp.
class IssuedCode {
  final String code;
  final DateTime? expiresAt;

  const IssuedCode({required this.code, this.expiresAt});

  factory IssuedCode.fromJson(Map<String, dynamic> json) => IssuedCode(
        code: (json['code'] as String?) ?? '',
        expiresAt: parseDate(json['expires_at']),
      );

  String get expiryLabel {
    final at = expiresAt;
    if (at == null) return 'No expiry set';
    final diff = at.difference(DateTime.now());
    if (diff.inHours <= 0) return 'Expires soon';
    if (diff.inHours < 24) return 'Expires in ${diff.inHours}h';
    return 'Expires in ${diff.inDays}d';
  }
}