import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../core/network/api_result.dart';
import '../../core/network/token_service.dart';
import '../../core/utils/logger.dart';
import '../../data/local/secure_storage.dart';
import '../../data/models/auth/auth_tokens.dart';
import '../../data/models/auth/auth_user.dart';
import '../../data/repositories/auth_repository.dart';

// ─────────────────────────────────────────────────────────────────────
// Storage + service providers
// ─────────────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureStorageInterface>(
  (ref) => SecureStorage(),
);

final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenService(storage: ref.read(secureStorageProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// ─────────────────────────────────────────────────────────────────────
// Session state
// ─────────────────────────────────────────────────────────────────────

/// The current session — full user + their tokens.
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

/// Holds the current session state and mediates persistence + restoration.
///
/// State transitions:
///   - `loading()`         → at app start, while restore is in flight
///   - `data(null)`        → signed out (no tokens / dead tokens)
///   - `data(Session)`     → signed in
///   - `error(...)`        → unrecoverable (rare; treat as signed out)
class SessionNotifier extends StateNotifier<AsyncValue<Session?>> {
  SessionNotifier({
    required TokenService tokenService,
    required AuthRepository authRepository,
  })  : _tokenService = tokenService,
        _authRepository = authRepository,
        super(const AsyncValue.loading());

  final TokenService _tokenService;
  final AuthRepository _authRepository;

  /// Called once from `SplashScreen.initState`. Reads persisted tokens,
  /// verifies them via `/auth/me`, and rebuilds the session.
  ///
  /// Returns the restored [AuthUser] on success, or `null` if the session
  /// is invalid. Always ends by setting state to `data(Session?)`.
  ///
  /// Behaviour per failure:
  ///   - No tokens stored        → `data(null)`, no server call
  ///   - `/auth/me` succeeds     → `data(Session)`, tokens refreshed if
  ///                                the interceptor rotated them
  ///   - `/auth/me` fails `auth` → clear tokens, `data(null)` — the
  ///                                refresh token was rejected too
  ///   - `/auth/me` fails other  → keep tokens (network blip, server 500),
  ///                                `data(null)` — next launch retries
  Future<AuthUser?> restoreSession() async {
    try {
      final storedTokens = await _tokenService.getStoredTokens();
      if (storedTokens == null) {
        state = const AsyncValue.data(null);
        return null;
      }

      final meResult = await _authRepository.me();

      switch (meResult) {
        case ApiSuccess(:final data):
          final freshTokens =
              await _tokenService.getStoredTokens() ?? storedTokens;
          await _tokenService.persistSession(user: data, tokens: freshTokens);
          state = AsyncValue.data(Session(user: data, tokens: freshTokens));
          return data;

        case ApiFailure(:final failure):
          if (failure.type == FailureType.auth) {
            await _tokenService.clearTokens();
          }
          state = const AsyncValue.data(null);
          return null;
      }
    } catch (e, st) {
      AppLogger.e('Session restore failed', error: e, stackTrace: st);
      state = const AsyncValue.data(null);
      return null;
    }
  }

    /// Signs out — revokes the current refresh token (or every session on
  /// every device when [allDevices] is true) and clears all local state.
  ///
  /// The server call is **best-effort**:
  ///   - If the network is down, we still sign out locally.
  ///   - If the token was already revoked (401), we still sign out locally.
  ///   - Any other error → same.
  ///
  /// Rationale: users must never be stuck "logged in" because of a backend
  /// hiccup. Worst case (server call fails), the tokens on the server side
  /// expire naturally within 14 days — but the device is clean immediately.
  ///
  /// For [allDevices]: if the call fails, other devices remain signed in.
  /// The user can retry from the login screen once we add a
  /// "revoke all sessions" affordance there (Phase 15). Not a blocker here.
  Future<void> logout({bool allDevices = false}) async {
    try {
      final tokens = await _tokenService.getStoredTokens();
      if (allDevices) {
        await _authRepository.logoutAll();
      } else {
        await _authRepository.logout(refreshToken: tokens?.refreshToken);
      }
    } catch (e, st) {
      AppLogger.w(
        'Logout backend call failed; clearing locally anyway',
        error: e,
        stackTrace: st,
      );
    }
    await _tokenService.clearTokens();
    state = const AsyncValue.data(null);
  }

  /// Called by the login screen on a successful `/auth/login`.
  Future<void> signIn({
    required AuthUser user,
    required AuthTokens tokens,
  }) async {
    await _tokenService.persistSession(user: user, tokens: tokens);
    state = AsyncValue.data(Session(user: user, tokens: tokens));
  }

  /// Called from the AppBar logout action (3.5).
  Future<void> signOut() async {
    await _tokenService.clearTokens();
    state = const AsyncValue.data(null);
  }

  /// Called by `ApiClient`'s `onSessionExpired` callback when the refresh
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
    StateNotifierProvider<SessionNotifier, AsyncValue<Session?>>((ref) {
  return SessionNotifier(
    tokenService: ref.read(tokenServiceProvider),
    authRepository: ref.read(authRepositoryProvider),
  );
});

/// Convenience selector — the current role, or null if signed out/loading.
final currentRoleProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider).valueOrNull?.role,
);

/// True if a session is active (not loading, not signed out).
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider).valueOrNull != null,
);

final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider).valueOrNull?.userId,
);

final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(sessionProvider).valueOrNull?.user,
);