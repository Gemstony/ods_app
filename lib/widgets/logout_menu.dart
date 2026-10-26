import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/route_names.dart';
import '../shared/providers/auth_provider.dart';

enum _LogoutAction { thisDevice, allDevices }

/// Account menu shown in every dashboard's AppBar.
///
/// Two actions, each confirmed:
///   - **Log out**               → `POST /auth/logout`
///   - **Log out from all devices** → `POST /auth/logout-all`
///
/// Both flows clear local tokens + session state and let the router's
/// `refreshListenable` redirect to `/login`. As a belt-and-braces measure,
/// the widget also calls `context.go('/login')` when it's still mounted —
/// in production the refreshListenable usually wins the race first.
class LogoutMenu extends ConsumerWidget {
  const LogoutMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_LogoutAction>(
      tooltip: 'Account',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => _handleLogout(context, ref, action),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _LogoutAction.thisDevice,
          // More horizontal room than the default 112–280px range, since
          // "Log out from all devices" is a long label.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
            child: const Row(
              children: [
                Icon(Icons.logout, size: 20),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Log out',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem(
          value: _LogoutAction.allDevices,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
            child: const Row(
              children: [
                Icon(Icons.devices_other, size: 20),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Log out from all devices',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout(
    BuildContext context,
    WidgetRef ref,
    _LogoutAction action,
  ) async {
    final confirmed = await _confirm(context, action);
    if (confirmed != true || !context.mounted) return;

    final isAllDevices = action == _LogoutAction.allDevices;

    await ref
        .read(sessionProvider.notifier)
        .logout(allDevices: isAllDevices);

    // If the widget is still mounted, navigate explicitly. In production
    // the router's refreshListenable usually fires first (session became
    // null → redirect to /login), making this a no-op. In tests where
    // refreshListenable isn't wired, this is what triggers the transition.
    if (context.mounted) {
      context.go(RouteNames.login);
    }
  }

  Future<bool?> _confirm(BuildContext context, _LogoutAction action) {
    final isAllDevices = action == _LogoutAction.allDevices;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isAllDevices ? 'Log out from all devices?' : 'Log out?'),
        content: Text(
          isAllDevices
              ? 'You will be signed out on every device where you are '
                  'currently logged in. You will need to sign in again on '
                  'each one.'
              : 'You will need to sign in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}