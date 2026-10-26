import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_router.dart';
import 'core/routing/role_guard.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/auth_provider.dart';

class OdsApp extends StatelessWidget {
  const OdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _OdsAppRoot());
  }
}

class _OdsAppRoot extends ConsumerStatefulWidget {
  const _OdsAppRoot();

  @override
  ConsumerState<_OdsAppRoot> createState() => _OdsAppRootState();
}

class _OdsAppRootState extends ConsumerState<_OdsAppRoot> {
  @override
  void initState() {
    super.initState();

    final container = ProviderScope.containerOf(context, listen: false);

    // Bridge the session provider to RoleGuard (read by go_router's redirect).
    RoleGuard.roleProvider =
        () => container.read(sessionProvider).valueOrNull?.role;

    // Wire TokenService into ApiClient so interceptors can read/write
    // the access token and auto-refresh on 401.
    final tokenService = container.read(tokenServiceProvider);
    ApiClient.instance.initialize(
      tokenService: tokenService,
      onSessionExpired: () async {
        // Refresh failed — the session is truly dead. Clear tokens and
        // sign out the session. Phase 3.4 flips `enforceAuth = true`,
        // which will then redirect to /login automatically.
        await tokenService.clearTokens();
        await container.read(sessionProvider.notifier).signOut();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.build(),
    );
  }
}