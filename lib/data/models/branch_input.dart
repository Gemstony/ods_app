import 'branch.dart';

/// The payload sent to `POST /owner/branches` and `PUT /owner/branches/{id}`.
///
/// Fields with a `null` value are omitted from JSON so the backend sees
/// no key — same semantics as passing `null` in a FormRequest, but a
/// smaller payload. `status` defaults to `active` (matches the backend's
/// DB default).
class BranchInput {
  final String name;
  final String code;
  final String address;
  final double latitude;
  final double longitude;
  final Map<String, dynamic>? operatingHours;
  final BranchStatus status;

  const BranchInput({
    required this.name,
    required this.code,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.operatingHours,
    this.status = BranchStatus.active,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      if (operatingHours != null) 'operating_hours': operatingHours,
      'status': status.name,
    };
  }
}