import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';

class OdsApp extends StatelessWidget {
  const OdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        home: const _BootScreen(),
      ),
    );
  }
}

/// Temporary boot screen. Verifies that Sub-phase 1.1 wiring works:
/// AppConfig is initialized, the env flag parsed, and the base URL resolved.
///
/// Removed in Sub-phase 1.5 when routing takes over.
class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.appName)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppConfig.appName,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(AppConfig.appTagline),
              const SizedBox(height: 32),
              _KeyValue(label: 'Environment', value: AppConfig.environment.name),
              _KeyValue(label: 'API base URL', value: AppConfig.apiBaseUrl),
              _KeyValue(label: 'App version', value: AppConfig.appVersion),
              const Spacer(),
              const Text(
                'Sub-phase 1.1 ✓\n'
                'Theme → 1.2   ·   Network → 1.4   ·   Routing → 1.5   ·   Role panels → 1.6',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}