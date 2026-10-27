/// Every named route in the app.
///
/// All navigation must go through these constants — no string literals in
/// widgets or redirect logic. Adding a route means adding a constant here.
class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String owner = '/owner';
  static const String manager = '/manager';
  static const String distributor = '/distributor';
  static const String rider = '/rider';
  static const String receiver = '/receiver';
  static const String accessDenied = '/denied';
}