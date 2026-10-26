import 'auth_tokens.dart';
import 'auth_user.dart';

/// What `/auth/login` and `/auth/refresh` both return: a user + a token pair.
class AuthLoginResult {
  final AuthUser user;
  final AuthTokens tokens;

  const AuthLoginResult({
    required this.user,
    required this.tokens,
  });

  /// Parses the backend envelope's `data` object.
  ///
  /// Expects `{ user: {...}, access_token, refresh_token, token_type, expires_in }`.
  factory AuthLoginResult.fromJson(Map<String, dynamic> data) {
    return AuthLoginResult(
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(data),
    );
  }
}