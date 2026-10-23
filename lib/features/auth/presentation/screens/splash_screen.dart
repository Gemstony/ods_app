import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';

/// Brand splash shown at app launch. Auto-navigates to `/login` after a short
/// delay; the router's redirect logic takes over from there (dormant until
/// Phase 3 enables `AppRouter.enforceAuth`).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(
      const Duration(milliseconds: 1500),
      () {
        if (!mounted) return;
        context.go(RouteNames.login);
      },
    );
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
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