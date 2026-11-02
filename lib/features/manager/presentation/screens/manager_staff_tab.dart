import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/auth/auth_user.dart';
import '../../../../widgets/widgets.dart';
import '../providers/manager_staff_providers.dart';
import 'staff_detail_screen.dart';
import 'staff_form_screen.dart';

class ManagerStaffTab extends ConsumerStatefulWidget {
  const ManagerStaffTab({super.key});

  @override
  ConsumerState<ManagerStaffTab> createState() => _ManagerStaffTabState();
}

class _ManagerStaffTabState extends ConsumerState<ManagerStaffTab> {
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
      final current = ref.read(managerStaffFilterProvider);
      ref.read(managerStaffFilterProvider.notifier).state = current.copyWith(
        search: value.trim().isEmpty ? null : value.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(managerStaffFilterProvider);
    final staffAsync = ref.watch(managerStaffProvider);

    return Column(
      children: [
        // Filter bar + search
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
                  ref.read(managerStaffFilterProvider.notifier).state =
                      filter.copyWith(role: role);
                },
                onStatusChanged: (status) {
                  ref.read(managerStaffFilterProvider.notifier).state =
                      filter.copyWith(status: status);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Staff list
        Expanded(
          child: staffAsync.when(
            loading: () => const LoadingView(message: 'Loading staff…'),
            error: (_, __) => ErrorView(
              message: 'Could not load staff.',
              onRetry: () => ref.invalidate(managerStaffProvider),
            ),
            data: (staff) {
              if (staff.isEmpty) {
                final hasFilters = filter.search != null ||
                    filter.role != null ||
                    filter.status != null;
                return EmptyView(
                  title: 'No staff found',
                  subtitle: hasFilters
                      ? 'Try clearing the filters.'
                      : 'Add your first Receiver or Rider to get started.',
                  icon: Icons.badge_outlined,
                  action: hasFilters
                      ? SizedBox(
                          width: 200,
                          child: AppButton(
                            label: 'Clear filters',
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(managerStaffFilterProvider.notifier)
                                  .state = const ManagerStaffFilter();
                            },
                            variant: AppButtonVariant.secondary,
                          ),
                        )
                      : SizedBox(
                          width: 200,
                          child: AppButton(
                            label: 'Add first staff',
                            onPressed: () => _openForm(context),
                            icon: Icons.add,
                          ),
                        ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(managerStaffProvider);
                  await ref.read(managerStaffProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: staff.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _StaffCard(
                    user: staff[i],
                    onTap: () => _openDetail(context, staff[i].id),
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
      builder: (_) => const StaffFormScreen(),
    ));
  }

  void _openDetail(BuildContext context, int id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StaffDetailScreen(staffId: id),
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
          _chip('All', currentRole == null && currentStatus == null, () {
            onRoleChanged(null);
            onStatusChanged(null);
          }),
          const SizedBox(width: AppSpacing.xs),
          _chip(
            'Receivers',
            currentRole == 'receiver',
            () => onRoleChanged(currentRole == 'receiver' ? null : 'receiver'),
          ),
          const SizedBox(width: AppSpacing.xs),
          _chip(
            'Riders',
            currentRole == 'rider',
            () => onRoleChanged(currentRole == 'rider' ? null : 'rider'),
          ),
          const SizedBox(width: AppSpacing.xs),
          _chip(
            'Suspended',
            currentStatus == 'suspended',
            () => onStatusChanged(
                currentStatus == 'suspended' ? null : 'suspended'),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Staff card
// ─────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final AuthUser user;
  final VoidCallback onTap;

  const _StaffCard({required this.user, required this.onTap});

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
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
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
                  if (user.role == 'receiver' && user.dispatcherEnabled)
                    const StatusChip(
                      label: 'Dispatcher',
                      type: StatusType.info,
                      isCompact: true,
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
        'suspended' => Icons.pause_circle,
        'deactivated' => Icons.block,
        _ => Icons.help_outline,
      };

  static Color _statusColor(String status) => switch (status) {
        'active' => AppColors.success,
        'suspended' => AppColors.error,
        'deactivated' => AppColors.onSurfaceMuted,
        _ => AppColors.onSurfaceMuted,
      };

  static String _statusLabel(String status) => switch (status) {
        'active' => 'Active',
        'suspended' => 'Suspended',
        'deactivated' => 'Deactivated',
        _ => status,
      };
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, type) = switch (role) {
      'rider' => ('Rider', StatusType.success),
      'receiver' => ('Receiver', StatusType.warning),
      _ => (role, StatusType.neutral),
    };
    return StatusChip(label: label, type: type, isCompact: true);
  }
}