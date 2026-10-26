import 'route_names.dart';

/// Single source of truth for "who is the current user?".
///
/// The router reads from here during every navigation event. Values are
/// injected once at app startup from `app.dart`, reading from
/// `sessionProvider`. Tests set the providers directly to simulate any
/// auth state.
class RoleGuard {
  RoleGuard._();

  /// Returns the current role, or null if signed out / still loading.
  static String? Function()? roleProvider;

  /// Returns true while session state is still resolving (initial
  /// `AsyncValue.loading()`). Router shows splash during this window and
  /// doesn't try to redirect to login — otherwise the user would see a
  /// flash of login before restore completes.
  static bool Function()? isRestoringProvider;

  static String? currentRole() => roleProvider?.call();
  static bool get isRestoring => isRestoringProvider?.call() ?? false;
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