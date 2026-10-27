import '../../core/utils/json_helpers.dart' as jh;

/// A single key-value configuration record.
///
/// Mirrors `App\Models\Setting` from Phase 2.4. The `value` is whatever the
/// backend stored — could be int, double, bool, String, List, or Map. Use
/// the typed getters ([asInt], [asBool], etc.) in call sites.
///
/// The `isPublic` flag indicates whether the setting can be read by
/// unauthenticated clients. Only `app.*` settings are typically public.
class Setting {
  final int id;
  final String key;
  final dynamic value;
  final String category;
  final String? description;
  final bool isPublic;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Setting({
    required this.id,
    required this.key,
    required this.value,
    required this.category,
    required this.isPublic,
    this.description,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Setting.fromJson(Map<String, dynamic> json) {
    return Setting(
      id: jh.asInt(json['id']),
      key: json['key'] as String,
      value: json['value'],
      category: json['category'] as String,
      description: json['description'] as String?,
      isPublic: jh.asBool(json['is_public']),
      updatedBy: json['updated_by'] == null ? null : jh.asInt(json['updated_by']),
      createdAt: jh.parseDate(json['created_at']),
      updatedAt: jh.parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'value': value,
        'category': category,
        'description': description,
        'is_public': isPublic,
        'updated_by': updatedBy,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  // ─── Typed getters ───────────────────────────────────────
  //
  // These throw a `TypeError` if the stored type doesn't match. That's
  // intentional — silent coercion of `true` → 1 → '1' leads to
  // extraordinarily painful bugs in config UI code.

  int get asInt {
    if (value is int) return value as int;
    if (value is double) return (value as double).toInt();
    if (value is String) return int.parse(value);
    throw TypeError();
  }

  double get asDouble {
    if (value is double) return value as double;
    if (value is int) return (value as int).toDouble();
    if (value is String) return double.parse(value);
    throw TypeError();
  }

  bool get asBool {
    if (value is bool) return value as bool;
    throw TypeError();
  }

  String get asString {
    if (value is String) return value as String;
    throw TypeError();
  }

  List<String> get asStringList {
    if (value is! List) throw TypeError();
    return (value as List).cast<String>();
  }

  /// Best-effort fallbacks — useful when the UI just needs to display a
  /// value and don't care about strict typing.
  String get displayValue {
    if (value == null) return '—';
    if (value is List) return value.join(', ');
    if (value is Map) {
      return (value as Map).entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
    return value.toString();
  }
}