import '../../core/utils/json_helpers.dart';
import 'delivery.dart';

/// The response from `POST /receiver/packages/{id}/verify`.
///
/// Phase 9.1 shape:
///   {
///     delivery:    Delivery,
///     can_release: bool,
///     reason:      String | null,
///     rider:       { id, name, phone } | null
///   }
///
/// The verify endpoint is a readiness check — it doesn't transition
/// state. Phase 12 extends it with a code match.
class PackageVerifyResult {
  final Delivery delivery;
  final bool canRelease;
  final String? reason;
  final RiderRef? rider;

  const PackageVerifyResult({
    required this.delivery,
    required this.canRelease,
    this.reason,
    this.rider,
  });

  factory PackageVerifyResult.fromJson(Map<String, dynamic> json) {
    final rawDelivery = json['delivery'];
    if (rawDelivery is! Map) {
      throw StateError('Missing delivery in verify response');
    }
    final rawRider = json['rider'];

    return PackageVerifyResult(
      delivery: Delivery.fromJson(
        Map<String, dynamic>.from(rawDelivery),
      ),
      canRelease: json['can_release'] == true,
      reason: json['reason'] as String?,
      rider: rawRider is Map && rawRider.isNotEmpty
          ? RiderRef.fromJson(Map<String, dynamic>.from(rawRider))
          : null,
    );
  }
}

/// Minimal rider reference returned by the verify endpoint.
class RiderRef {
  final int id;
  final String name;
  final String phone;

  const RiderRef({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory RiderRef.fromJson(Map<String, dynamic> json) {
    return RiderRef(
      id: asInt(json['id']),
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }
}