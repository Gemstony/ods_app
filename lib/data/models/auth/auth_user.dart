/// A user returned by the backend's `/auth/login`, `/auth/refresh`, and
/// `/auth/me` endpoints.
///
/// Mirrors `App\Http\Resources\UserResource` exactly. Rider-specific fields
/// are nullable so any role's JSON parses cleanly.
class AuthUser {
  final int id;
  final String name;
  final String email;
  final String phone;

  /// One of: 'owner' | 'manager' | 'distributor' | 'rider' | 'receiver'.
  final String role;

  /// One of: 'pending' | 'active' | 'suspended' | 'deactivated'.
  final String status;

  final int? branchId;
  final String? distributorId;
  final bool dispatcherEnabled;
  final DateTime? emailVerifiedAt;
  final DateTime? createdAt;

  /// Permission names granted to this user's role.
  /// Populated when the backend includes the `role.permissions` relation.
  final List<String> permissions;

  // ─── Rider-specific (null for other roles) ─────────────────
  final String? nida;
  final String? sex;
  final DateTime? dateOfBirth;
  final String? vehicleType;
  final String? vehicleColor;
  final String? vehicleOwnership;
  final String? plateNumber;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.dispatcherEnabled,
    required this.permissions,
    this.branchId,
    this.distributorId,
    this.emailVerifiedAt,
    this.createdAt,
    this.nida,
    this.sex,
    this.dateOfBirth,
    this.vehicleType,
    this.vehicleColor,
    this.vehicleOwnership,
    this.plateNumber,
  });

  /// Parses the backend `data.user` object.
  ///
  /// Numeric and boolean fields use safe fallbacks (`_asInt`, `_asBool`)
  /// because JSON decoders don't guarantee type on optional fields — a
  /// missing `dispatcher_enabled` shouldn't crash the app.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: _asInt(json['id']),
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      branchId: json['branch_id'] == null ? null : _asInt(json['branch_id']),
      distributorId: json['distributor_id'] as String?,
      dispatcherEnabled: _asBool(json['dispatcher_enabled']),
      emailVerifiedAt: _parseDate(json['email_verified_at']),
      createdAt: _parseDate(json['created_at']),
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      nida: json['nida'] as String?,
      sex: json['sex'] as String?,
      dateOfBirth: _parseDate(json['date_of_birth']),
      vehicleType: json['vehicle_type'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      vehicleOwnership: json['vehicle_ownership'] as String?,
      plateNumber: json['plate_number'] as String?,
    );
  }

  // ─── Convenience helpers (used by 3.3–3.5) ────────────────
  bool get isOwner       => role == 'owner';
  bool get isManager     => role == 'manager';
  bool get isDistributor => role == 'distributor';
  bool get isRider       => role == 'rider';
  bool get isReceiver    => role == 'receiver';
  bool get isActive      => status == 'active';

  bool hasPermission(String name) => permissions.contains(name);

  // ─── Internal parsers ─────────────────────────────────────
  static int _asInt(dynamic v) => v is int ? v : int.parse(v.toString());
  static bool _asBool(dynamic v) =>
      v is bool ? v : (v == 1 || v == '1' || v == 'true');
  static DateTime? _parseDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}