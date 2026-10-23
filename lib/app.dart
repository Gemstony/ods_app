import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
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
    // Bridge the session provider to RoleGuard (read by go_router's redirect).
    //
    // Using ProviderScope.containerOf gives us a stable container reference
    // that survives widget rebuilds — unlike capturing `ref` in a closure.
    final container = ProviderScope.containerOf(context, listen: false);
    RoleGuard.roleProvider =
        () => container.read(sessionProvider).valueOrNull?.role;
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