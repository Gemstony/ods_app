import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/token_service.dart';
import '../../core/utils/logger.dart';
import '../../data/local/secure_storage.dart';
import '../../data/models/auth/auth_tokens.dart';
import '../../data/models/auth/auth_user.dart';

// ─────────────────────────────────────────────────────────────────────
// Storage providers
// ─────────────────────────────────────────────────────────────────────

/// Provides the [SecureStorageInterface] implementation the app should use.
///
/// Tests override this with `InMemorySecureStorage`. Production uses the
/// real `SecureStorage` (Keychain / EncryptedSharedPreferences).
final secureStorageProvider = Provider<SecureStorageInterface>(
  (ref) => SecureStorage(),
);

/// Provides the app's [TokenService].
///
/// Depends on [secureStorageProvider] so tests can override the storage
/// implementation without touching this provider.
final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenService(storage: ref.read(secureStorageProvider));
});

// ─────────────────────────────────────────────────────────────────────
// Session state
// ─────────────────────────────────────────────────────────────────────

/// The current session — a full user + their tokens.
///
/// Wrapped in a class (not a nullable record) so Phase 3.4 can add
/// "session restored" flags or metadata without churning every provider.
class Session {
  final AuthUser user;
  final AuthTokens tokens;

  const Session({required this.user, required this.tokens});

  String get userId => user.id.toString();
  String get role => user.role;
  String? get branchId => user.branchId?.toString();
  String? get displayName => user.name;
  List<String> get permissions => user.permissions;
}

// ─────────────────────────────────────────────────────────────────────
// Session notifier
// ─────────────────────────────────────────────────────────────────────

/// Holds the current session state and mediates persistence.
///
/// State shape:
///   - `AsyncValue.loading()`     → startup (brief; resolves to null)
///   - `AsyncValue.data(null)`    → no session (signed out)
///   - `AsyncValue.data(Session)` → signed in
///   - `AsyncValue.error(...)`    → storage failure (recoverable via signOut)
///
/// NOTE: pre-3.4, this class does NOT restore a session from storage on
/// app startup. Restoring a Session requires calling `/auth/me` to
/// rebuild the `AuthUser` from the server — a network operation with
/// proper loading and error handling. That is Phase 3.4's job. Pre-3.4,
/// app reload = signed out, which is intentional and honest.
class SessionNotifier extends StateNotifier<AsyncValue<Session?>> {
  SessionNotifier({required TokenService tokenService})
      : _tokenService = tokenService,
        super(const AsyncValue.data(null)); // start signed-out

  final TokenService _tokenService;

  /// Called by the login screen on a successful `/auth/login`.
  ///
  /// Persists tokens first, then updates in-memory state — so any widget
  /// rebuilt by the state change sees a consistent world where storage
  /// and state agree.
  Future<void> signIn({
    required AuthUser user,
    required AuthTokens tokens,
  }) async {
    await _tokenService.persistSession(user: user, tokens: tokens);
    state = AsyncValue.data(Session(user: user, tokens: tokens));
  }

  /// Clears the session from memory and secure storage.
  Future<void> signOut() async {
    await _tokenService.clearTokens();
    state = const AsyncValue.data(null);
  }

  /// Called by [ApiClient]'s `onSessionExpired` callback when the refresh
  /// interceptor has determined the session is truly dead.
  Future<void> handleSessionExpired() async {
    AppLogger.i('Session expired — clearing tokens and signing out');
    await _tokenService.clearTokens();
    state = const AsyncValue.data(null);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────

final sessionProvider =
    StateNotifierProvider<SessionNotifier, AsyncValue<Session?>>(
  (ref) => SessionNotifier(tokenService: ref.read(tokenServiceProvider)),
);

/// Convenience selector — the current role, or null if signed out.
/// `RoleGuard.roleProvider` is wired to read from this.
final currentRoleProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider).valueOrNull?.role,
);

/// Convenience selector — true if a session is active.
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider).valueOrNull != null,
);

/// Convenience selector — current user id, or null.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider).valueOrNull?.userId,
);

/// Convenience selector — the full user (for screens that need
/// permissions, branch_id, etc.).
final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(sessionProvider).valueOrNull?.user,
);