import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/auth/auth_user.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/dashboard_providers.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_branch_providers.dart';
import '../providers/owner_user_providers.dart';

class UserDetailScreen extends ConsumerWidget {
  final int userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(ownerUserProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: userAsync.maybeWhen(
          data: (u) => Text(u.name),
          orElse: () => const Text('User'),
        ),
      ),
      body: userAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorView(
          message: 'Could not load user.',
          onRetry: () => ref.invalidate(ownerUserProvider(userId)),
        ),
        data: (user) => _UserDetailContent(user: user),
      ),
    );
  }
}

class _UserDetailContent extends ConsumerWidget {
  final AuthUser user;
  const _UserDetailContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        _InfoCard(user: user),
        if (user.role == 'rider') ...[
          const SizedBox(height: AppSpacing.lg),
          _RiderCard(user: user),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ActionsCard(user: user),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─── Info card ─────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final AuthUser user;
  const _InfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      _kv(context, 'Email', user.email),
      _kv(context, 'Phone', user.phone),
      _kv(context, 'Role', user.role),
      if (user.branch != null)
        _kv(context, 'Branch',
            '${user.branch!.name} (${user.branch!.code})'),
      if (user.distributorId != null)
        _kv(context, 'Distributor ID', user.distributorId!),
      Row(
        children: [
          Expanded(
            child: Text(
              'Status',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
            ),
          ),
          _StatusChip(status: user.status),
        ],
      ),
      if (user.role == 'receiver')
        _kv(
          context,
          'Dispatcher',
          user.dispatcherEnabled ? 'Enabled' : 'Not enabled',
        ),
    ]);
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rider card ────────────────────────────────────────────

class _RiderCard extends StatelessWidget {
  final AuthUser user;
  const _RiderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      Row(
        children: [
          const Icon(Icons.delivery_dining, color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Rider details',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      _kv(context, 'NIDA', user.nida ?? '—'),
      _kv(context, 'Sex', user.sex ?? '—'),
      _kv(context, 'Date of birth',
          user.dateOfBirth?.toIso8601String().split('T').first ?? '—'),
      _kv(context, 'Vehicle', user.vehicleType ?? '—'),
      _kv(context, 'Color', user.vehicleColor ?? '—'),
      _kv(context, 'Ownership', user.vehicleOwnership ?? '—'),
      _kv(context, 'Plate', user.plateNumber ?? '—'),
    ]);
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Actions card ──────────────────────────────────────────

class _ActionsCard extends ConsumerWidget {
  final AuthUser user;
  const _ActionsCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SurfaceCard(children: [
      if (user.status == 'pending')
        AppButton(
          label: 'Approve account',
          onPressed: () => _approve(context, ref),
          icon: Icons.check_circle_outline,
        )
      else ...[
        if (user.status == 'active')
          AppButton(
            label: 'Suspend account',
            onPressed: () => _changeStatus(context, ref, 'suspended'),
            variant: AppButtonVariant.secondary,
            icon: Icons.pause_circle_outline,
          )
        else if (user.status == 'suspended')
          AppButton(
            label: 'Reactivate account',
            onPressed: () => _changeStatus(context, ref, 'active'),
            variant: AppButtonVariant.secondary,
            icon: Icons.play_circle_outline,
          ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Reset password',
          onPressed: () => _resetPassword(context, ref),
          variant: AppButtonVariant.text,
          icon: Icons.lock_reset,
        ),
      ],
    ]);
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(userRepositoryProvider);
    final result = await repo.approve(user.id);

    if (!context.mounted) return;

    result.fold(
      onSuccess: (_) {
        ref.invalidate(ownerUserProvider(user.id));
        ref.invalidate(ownerUsersProvider);
        ref.invalidate(ownerDashboardProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account approved.')),
        );
      },
      onFailure: (failure) => _showError(context, failure.message),
    );
  }

  Future<void> _changeStatus(
      BuildContext context, WidgetRef ref, String status) async {
    final confirmed = await _confirmStatusChange(context, status);
    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(userRepositoryProvider);
    final result = await repo.updateStatus(user.id, status);

    if (!context.mounted) return;

    result.fold(
      onSuccess: (_) {
        ref.invalidate(ownerUserProvider(user.id));
        ref.invalidate(ownerUsersProvider);
        ref.invalidate(ownerDashboardProvider);
      },
      onFailure: (failure) => _showError(context, failure.message),
    );
  }

  Future<bool?> _confirmStatusChange(BuildContext context, String status) {
    final label = switch (status) {
      'suspended' => 'Suspend',
      'active' => 'Reactivate',
      'deactivated' => 'Deactivate',
      _ => 'Change status to',
    };

    return showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('$label ${user.name}?'),
        content: Text(
          status == 'suspended'
              ? 'Their active sessions will be revoked immediately. '
                  'They will need to be reactivated to sign in.'
              : 'They will be able to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref) async {
    final controllers = await showDialog<(String, String)?>(
      context: context,
      builder: (d) => const _ResetPasswordDialog(),
    );
    if (controllers == null || !context.mounted) return;

    final repo = ref.read(userRepositoryProvider);
    final result = await repo.resetPassword(
      user.id,
      password: controllers.$1,
      passwordConfirmation: controllers.$2,
    );

    if (!context.mounted) return;

    result.fold(
      onSuccess: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Share it securely.')),
      ),
      onFailure: (failure) => _showError(context, failure.message),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ));
  }
}

// ─── Reset password dialog ─────────────────────────────────

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog();

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final p = _password.text;
    final c = _confirm.text;
    if (p.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (p != c) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    Navigator.of(context).pop((p, c));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration:
                const InputDecoration(labelText: 'Confirm password'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Reset'),
        ),
      ],
    );
  }
}

// ─── Status chip ───────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, type) = switch (status) {
      'active' => ('Active', StatusType.success),
      'pending' => ('Pending approval', StatusType.warning),
      'suspended' => ('Suspended', StatusType.error),
      'deactivated' => ('Deactivated', StatusType.neutral),
      _ => (status, StatusType.neutral),
    };
    return StatusChip(label: label, type: type, isCompact: true);
  }
}

// ─── Shared surface ────────────────────────────────────────

class _SurfaceCard extends StatelessWidget {
  final List<Widget> children;
  const _SurfaceCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}