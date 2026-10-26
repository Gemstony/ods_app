import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_router.dart';
import 'core/routing/role_guard.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/auth_provider.dart';

class OdsApp extends StatelessWidget {
  /// Optional Riverpod overrides. Tests inject `secureStorageProvider` /
  /// `authRepositoryProvider` here to control the session-restore path
  /// without touching production code.
  final List<Override> overrides;

  const OdsApp({super.key, this.overrides = const []});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: const _OdsAppRoot(),
    );
  }
}

class _OdsAppRoot extends ConsumerStatefulWidget {
  const _OdsAppRoot();

  @override
  ConsumerState<_OdsAppRoot> createState() => _OdsAppRootState();
}

class _OdsAppRootState extends ConsumerState<_OdsAppRoot> {
  late final _SessionRefreshNotifier _refreshNotifier;
  late final RouterConfig<Object> _router;

  @override
  void initState() {
    super.initState();

    final container = ProviderScope.containerOf(context, listen: false);

    RoleGuard.roleProvider =
        () => container.read(sessionProvider).valueOrNull?.role;
    RoleGuard.isRestoringProvider =
        () => container.read(sessionProvider).isLoading;

    final tokenService = container.read(tokenServiceProvider);
    ApiClient.instance.initialize(
      tokenService: tokenService,
      onSessionExpired: () async {
        await container.read(sessionProvider.notifier).handleSessionExpired();
      },
    );

    _refreshNotifier = _SessionRefreshNotifier(container);
    _router = AppRouter.build(refreshListenable: _refreshNotifier);
  }

  @override
  void dispose() {
    _refreshNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

class _SessionRefreshNotifier extends ChangeNotifier {
  _SessionRefreshNotifier(ProviderContainer container) {
    _subscription = container.listen(
      sessionProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}