/// Shared helpers for parsing backend JSON that uses loosely-typed numbers
/// and dates.
///
/// Laravel's `decimal(12,2)` casts produce `500.0` (double), `integer`
/// produces `500` (int), and some responses can serialize `id` as `"42"`
/// (string). The `asX` helpers normalise all three into the expected Dart
/// type, throwing only when the value is genuinely unparseable.

/// Parses an int from an int or numeric string. Throws on garbage.
int asInt(dynamic v) {
  if (v is int) return v;
  if (v is String) return int.parse(v);
  if (v is double) return v.toInt();
  throw FormatException('Cannot parse int from $v (${v.runtimeType})');
}

/// Parses a double from a double, int, or numeric string. Throws on garbage.
double asDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.parse(v);
  throw FormatException('Cannot parse double from $v (${v.runtimeType})');
}

/// Parses a bool from a bool, 0/1, or "true"/"false". Throws on garbage.
bool asBool(dynamic v) {
  if (v is bool) return v;
  if (v == 1 || v == '1' || v == 'true') return true;
  if (v == 0 || v == '0' || v == 'false') return false;
  throw FormatException('Cannot parse bool from $v (${v.runtimeType})');
}

/// Parses an ISO 8601 timestamp. Returns null for null / unparseable.
DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

/// Coerces a `dynamic` map (from `json['key']`) into a `Map<String, dynamic>?`.
/// Returns null when the input is null or not a map.
Map<String, dynamic>? asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

/// Coerces a `dynamic` list into `List<T>?` using [itemFromJson].
List<T>? asList<T>(
  dynamic v,
  T Function(Map<String, dynamic> json) itemFromJson,
) {
  if (v is! List) return null;
  return v
      .whereType<Map>()
      .map((item) => itemFromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}