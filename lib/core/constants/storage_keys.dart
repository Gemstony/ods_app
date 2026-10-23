/// Keys used by [SecureStorage]. Centralized so no string literals leak
/// into feature code — a typo'd key would silently "log the user out".
class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'ods.auth.access_token';
  static const String refreshToken = 'ods.auth.refresh_token';
  static const String userRole = 'ods.auth.role';
  static const String userId = 'ods.auth.user_id';
  static const String displayName = 'ods.auth.display_name';
  static const String lastActivityAt = 'ods.auth.last_activity_at';
}