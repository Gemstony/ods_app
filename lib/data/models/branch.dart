import '../../core/utils/json_helpers.dart';

/// A physical NeoLife pickup branch operating under ODS.
///
/// Mirrors the backend `App\Models\Branch` from Phase 2.2. The `code` is a
/// short human-readable identifier (e.g., "DSM-01") — used in UI labels and
/// receipt text.
enum BranchStatus {
  active,
  inactive;

  /// Parses the string the backend sends. Falls back to [inactive] for
  /// unknown values so a future status added server-side never crashes
  /// the app — the branch simply appears as closed until Flutter ships
  /// an update.
  static BranchStatus fromString(String value) {
    return BranchStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BranchStatus.inactive,
    );
  }
}

class Branch {
  final int id;
  final String name;
  final String code;
  final String address;
  final double latitude;
  final double longitude;

  /// Raw operating hours — a map of day names to `{"open":"08:00","close":"18:00"}`
  /// or `null` for closed days. Typed sub-model deferred until a screen
  /// needs structured access.
  final Map<String, dynamic>? operatingHours;

  final BranchStatus status;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Branch({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.operatingHours,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: asInt(json['id']),
      name: json['name'] as String,
      code: json['code'] as String,
      address: json['address'] as String,
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      operatingHours: asMap(json['operating_hours']),
      status: BranchStatus.fromString(json['status'] as String),
      createdBy: json['created_by'] == null ? null : asInt(json['created_by']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      deletedAt: parseDate(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'operating_hours': operatingHours,
        'status': status.name,
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };

  // ─── Helpers used by UI screens ───────────────────────────
  bool get isActive => status == BranchStatus.active;
  bool get isDeleted => deletedAt != null;

  /// The latitude/longitude as a single string for display / logging.
  String get coordinates => '${latitude.toStringAsFixed(5)}, '
      '${longitude.toStringAsFixed(5)}';
}