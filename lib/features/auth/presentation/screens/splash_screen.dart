import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/routing/role_guard.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/auth_provider.dart';

/// Brand splash + session restore.
///
/// Runs `restoreSession()` and a 1.5s minimum-duration timer in parallel.
/// When both complete, routes to the role's home (if restored) or to
/// `/login` (if not). Router redirects are suspended while we're on splash
/// — this screen owns startup navigation.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Kick off restore and the branding delay concurrently.
    await Future.wait([
      ref.read(sessionProvider.notifier).restoreSession(),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);

    if (!mounted) return;

    final session = ref.read(sessionProvider).valueOrNull;
    if (session != null) {
      context.go(RoleGuard.homeForRole(session.role));
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_shipping_rounded,
                size: 96,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                AppConfig.appName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              SizedBox(height: 6),
              Text(
                AppConfig.appTagline,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}