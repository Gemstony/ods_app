import 'route_names.dart';

/// Single source of truth for "what is the current user's role?".
///
/// This is a stub for Phase 1.5 — [roleProvider] is null, so [currentRole]
/// always returns null. Sub-phase 1.8 wires a Riverpod auth provider into it;
/// Phase 3 replaces the provider with the real auth state.
///
/// Keeping the "what role" question isolated here means the router, screens,
/// and future deep-link handlers never import auth internals directly.
class RoleGuard {
  RoleGuard._();

  /// Injected function that returns the current role, or null if signed out.
  /// Set once at app startup (Sub-phase 1.8).
  static String? Function()? roleProvider;

  static String? currentRole() => roleProvider?.call();

  static bool get isAuthenticated => currentRole() != null;

  /// Maps a role string to its home route.
  static String homeForRole(String role) => switch (role) {
        'owner' => RouteNames.owner,
        'manager' => RouteNames.manager,
        'distributor' => RouteNames.distributor,
        'rider' => RouteNames.rider,
        'receiver' => RouteNames.receiver,
        _ => RouteNames.login,
      };
}