import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/logger.dart';
import '../../data/local/secure_storage.dart';
import '../../core/network/token_service.dart';

// ─────────────────────────────────────────────────────────────────────
// Session model
// ─────────────────────────────────────────────────────────────────────

/// An authenticated session.
///
/// Deliberately minimal — holds just what the UI and router need to know.
/// Full user profile (name, email, branch, etc.) arrives in Phase 3 with the
/// real auth flow.
class Session {
  final String userId;
  final String role;
  final String accessToken;
  final String? displayName;

  const Session({
    required this.userId,
    required this.role,
    required this.accessToken,
    this.displayName,
  });

  @override
  String toString() =>
      'Session(userId: $userId, role: $role, displayName: $displayName)';
}

// ─────────────────────────────────────────────────────────────────────
// Storage provider (injectable for tests)
// ─────────────────────────────────────────────────────────────────────

/// Provides the [SecureStorageInterface] implementation the app should use.
///
/// Tests override this with `InMemorySecureStorage`. Production uses the
/// real `SecureStorage` (Keychain / EncryptedSharedPreferences).
final secureStorageProvider = Provider<SecureStorageInterface>(
  (ref) => SecureStorage(),
);

/// Depends on [secureStorageProvider] so tests can override the storage
/// implementation without touching this provider.
final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenService(storage: ref.read(secureStorageProvider));
});

// ─────────────────────────────────────────────────────────────────────
// Session notifier
// ─────────────────────────────────────────────────────────────────────

/// Holds the current session state and mediates persistence.
///
/// State shape:
///   - `AsyncValue.loading()`       → reading from storage at startup
///   - `AsyncValue.data(null)`      → no session (signed out)
///   - `AsyncValue.data(Session)`   → signed in
///   - `AsyncValue.error(...)`      → storage failure (rare; recoverable by
///                                    the "sign out" dev button)
class SessionNotifier extends StateNotifier<AsyncValue<Session?>> {
  SessionNotifier({required SecureStorageInterface storage})
      : _storage = storage,
        super(const AsyncValue.loading()) {
    _loadFromStorage();
  }

  final SecureStorageInterface _storage;

  Future<void> _loadFromStorage() async {
    try {
      final token = await _storage.read(StorageKeys.accessToken);
      final role = await _storage.read(StorageKeys.userRole);
      final userId = await _storage.read(StorageKeys.userId);
      final displayName = await _storage.read(StorageKeys.displayName);

      if (token != null && role != null && userId != null) {
        state = AsyncValue.data(Session(
          userId: userId,
          role: role,
          accessToken: token,
          displayName: displayName,
        ));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      // A storage read failure shouldn't wedge the app — treat as signed out.
      AppLogger.e('Failed to load session from storage',
          error: e, stackTrace: st);
      state = const AsyncValue.data(null);
    }
  }

  /// Signs in and persists the session.
  ///
  /// Phase 3 replaces the direct call with a real API round-trip; the
  /// persistence and state-update logic stay exactly as written here.
  Future<void> signIn({
    required String userId,
    required String role,
    required String accessToken,
    String? displayName,
    String? refreshToken,
  }) async {
    await _storage.write(StorageKeys.accessToken, accessToken);
    await _storage.write(StorageKeys.userRole, role);
    await _storage.write(StorageKeys.userId, userId);
    if (displayName != null) {
      await _storage.write(StorageKeys.displayName, displayName);
    }
    if (refreshToken != null) {
      await _storage.write(StorageKeys.refreshToken, refreshToken);
    }

    state = AsyncValue.data(Session(
      userId: userId,
      role: role,
      accessToken: accessToken,
      displayName: displayName,
    ));
  }

  /// Clears the session from memory and secure storage.
  Future<void> signOut() async {
    await _storage.delete(StorageKeys.accessToken);
    await _storage.delete(StorageKeys.refreshToken);
    await _storage.delete(StorageKeys.userRole);
    await _storage.delete(StorageKeys.userId);
    await _storage.delete(StorageKeys.displayName);
    await _storage.delete(StorageKeys.lastActivityAt);

    state = const AsyncValue.data(null);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────

final sessionProvider =
    StateNotifierProvider<SessionNotifier, AsyncValue<Session?>>(
  (ref) => SessionNotifier(storage: ref.read(secureStorageProvider)),
);

/// Convenience selector — the current role, or null if signed out.
///
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