import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/auth/auth_user.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_user_providers.dart';
import 'user_detail_screen.dart';
import 'user_form_screen.dart';

class OwnerUsersTab extends ConsumerStatefulWidget {
  const OwnerUsersTab({super.key});

  @override
  ConsumerState<OwnerUsersTab> createState() => _OwnerUsersTabState();
}

class _OwnerUsersTabState extends ConsumerState<OwnerUsersTab> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final current = ref.read(ownerUsersFilterProvider);
      ref.read(ownerUsersFilterProvider.notifier).state =
          current.copyWith(search: value.trim().isEmpty ? null : value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(ownerUsersFilterProvider);
    final usersAsync = ref.watch(ownerUsersProvider);

    return Column(
      children: [
        // ─── Filter bar + search ───────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _searchController,
                label: 'Search',
                hint: 'Name, email, or phone',
                prefixIcon: Icons.search,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
              ),
              const SizedBox(height: AppSpacing.sm),
              _FilterChips(
                currentRole: filter.role,
                currentStatus: filter.status,
                onRoleChanged: (role) {
                  ref.read(ownerUsersFilterProvider.notifier).state =
                      filter.copyWith(role: role);
                },
                onStatusChanged: (status) {
                  ref.read(ownerUsersFilterProvider.notifier).state =
                      filter.copyWith(status: status);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ─── Users list ────────────────────────────────────
        Expanded(
          child: usersAsync.when(
            loading: () => const LoadingView(message: 'Loading users…'),
            error: (_, __) => ErrorView(
              message: 'Could not load users.',
              onRetry: () => ref.invalidate(ownerUsersProvider),
            ),
            data: (users) {
              if (users.isEmpty) {
                return EmptyView(
                  title: 'No users found',
                  subtitle: filter.search != null ||
                          filter.role != null ||
                          filter.status != null
                      ? 'Try clearing the filters.'
                      : 'Add your first team member to get started.',
                  icon: Icons.people_outline,
                  action: filter.search != null ||
                          filter.role != null ||
                          filter.status != null
                      ? SizedBox(
                          width: 200,
                          child: AppButton(
                            label: 'Clear filters',
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(ownerUsersFilterProvider.notifier)
                                  .state = const OwnerUsersFilter();
                            },
                            variant: AppButtonVariant.secondary,
                          ),
                        )
                      : SizedBox(
                          width: 200,
                          child: AppButton(
                            label: 'Add first user',
                            onPressed: () => _openForm(context),
                            icon: Icons.add,
                          ),
                        ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ownerUsersProvider);
                  await ref.read(ownerUsersProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: users.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _UserCard(
                    user: users[i],
                    onTap: () => _openDetail(context, users[i].id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const UserFormScreen(),
    ));
  }

  void _openDetail(BuildContext context, int id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UserDetailScreen(userId: id),
    ));
  }
}

// ─────────────────────────────────────────────────────────────
// Filter chips
// ─────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final String? currentRole;
  final String? currentStatus;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onStatusChanged;

  const _FilterChips({
    required this.currentRole,
    required this.currentStatus,
    required this.onRoleChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', null, currentRole == null, () => onRoleChanged(null)),
          const SizedBox(width: AppSpacing.xs),
          _chip('Pending', null, currentStatus == 'pending',
              () => onStatusChanged(
                    currentStatus == 'pending' ? null : 'pending',
                  )),
          const SizedBox(width: AppSpacing.xs),
          _chip('Managers', 'manager', currentRole == 'manager',
              () => onRoleChanged(
                    currentRole == 'manager' ? null : 'manager',
                  )),
          const SizedBox(width: AppSpacing.xs),
          _chip('Distributors', 'distributor', currentRole == 'distributor',
              () => onRoleChanged(
                    currentRole == 'distributor' ? null : 'distributor',
                  )),
          const SizedBox(width: AppSpacing.xs),
          _chip('Riders', 'rider', currentRole == 'rider',
              () => onRoleChanged(currentRole == 'rider' ? null : 'rider')),
          const SizedBox(width: AppSpacing.xs),
          _chip('Receivers', 'receiver', currentRole == 'receiver',
              () => onRoleChanged(
                    currentRole == 'receiver' ? null : 'receiver',
                  )),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// User card
// ─────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final AuthUser user;
  final VoidCallback onTap;

  const _UserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.surface,
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.email,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _RoleBadge(role: user.role),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    _statusIcon(user.status),
                    size: 14,
                    color: _statusColor(user.status),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    _statusLabel(user.status),
                    style: text.bodySmall?.copyWith(
                      color: _statusColor(user.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (user.branch != null)
                    Flexible(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.store_outlined,
                            size: 12,
                            color: AppColors.onSurfaceMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              user.branch!.name,
                              style: text.bodySmall?.copyWith(
                                color: AppColors.onSurfaceMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _statusIcon(String status) => switch (status) {
        'active' => Icons.check_circle,
        'pending' => Icons.schedule,
        'suspended' => Icons.pause_circle,
        'deactivated' => Icons.block,
        _ => Icons.help_outline,
      };

  static Color _statusColor(String status) => switch (status) {
        'active' => AppColors.success,
        'pending' => AppColors.warning,
        'suspended' => AppColors.error,
        'deactivated' => AppColors.onSurfaceMuted,
        _ => AppColors.onSurfaceMuted,
      };

  static String _statusLabel(String status) => switch (status) {
        'active' => 'Active',
        'pending' => 'Pending approval',
        'suspended' => 'Suspended',
        'deactivated' => 'Deactivated',
        _ => status,
      };
}

// ─────────────────────────────────────────────────────────────
// Role badge
// ─────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, type) = switch (role) {
      'owner' => ('Owner', StatusType.primary),
      'manager' => ('Manager', StatusType.info),
      'distributor' => ('Distributor', StatusType.neutral),
      'rider' => ('Rider', StatusType.success),
      'receiver' => ('Receiver', StatusType.warning),
      _ => (role, StatusType.neutral),
    };

    return StatusChip(label: label, type: type, isCompact: true);
  }
}