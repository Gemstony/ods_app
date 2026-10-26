/// The token pair returned by `/auth/login` and `/auth/refresh`.
///
/// `accessToken` is a JWT (sent as `Authorization: Bearer …`).
/// `refreshToken` is a 64-char opaque hex string, rotated on every use.
///
/// `expiresIn` is in **seconds** — matches what the backend sends. Use
/// `accessExpiryDate` for a `DateTime` when scheduling a refresh.
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresIn: json['expires_in'] is int
          ? json['expires_in'] as int
          : int.parse(json['expires_in'].toString()),
    );
  }

  /// Absolute time when the access token expires, computed from now.
  DateTime get accessExpiryDate =>
      DateTime.now().add(Duration(seconds: expiresIn));
}