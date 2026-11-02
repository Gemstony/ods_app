import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ods_app/features/shared/presentation/screens/delivery_detail_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../widgets/widgets.dart';
import '../providers/manager_delivery_providers.dart';

/// The Manager's Deliveries tab — branch-scoped delivery list.
class ManagerDeliveriesTab extends ConsumerStatefulWidget {
  const ManagerDeliveriesTab({super.key});

  @override
  ConsumerState<ManagerDeliveriesTab> createState() =>
      _ManagerDeliveriesTabState();
}

class _ManagerDeliveriesTabState extends ConsumerState<ManagerDeliveriesTab> {
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
      final current = ref.read(managerDeliveriesFilterProvider);
      ref.read(managerDeliveriesFilterProvider.notifier).state =
          current.copyWith(
        search: value.trim().isEmpty ? null : value.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(managerDeliveriesFilterProvider);
    final deliveriesAsync = ref.watch(managerDeliveriesProvider);

    return Column(
      children: [
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
                hint: 'Tracking ID',
                prefixIcon: Icons.search,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
              ),
              const SizedBox(height: AppSpacing.sm),
              _FilterChips(filter: filter),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: deliveriesAsync.when(
            loading: () => const LoadingView(message: 'Loading deliveries…'),
            error: (_, __) => ErrorView(
              message: 'Could not load deliveries.',
              onRetry: () => ref.invalidate(managerDeliveriesProvider),
            ),
            data: (deliveries) {
              if (deliveries.isEmpty) {
                final hasFilter = filter.statuses != null ||
                    filter.serviceType != null ||
                    filter.search != null;
                return EmptyView(
                  title: 'No deliveries',
                  subtitle: hasFilter
                      ? 'Try clearing the filters.'
                      : 'Deliveries will appear here as they come in.',
                  icon: Icons.local_shipping_outlined,
                  action: hasFilter
                      ? SizedBox(
                          width: 200,
                          child: AppButton(
                            label: 'Clear filters',
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(managerDeliveriesFilterProvider.notifier)
                                  .state = const ManagerDeliveriesFilter();
                            },
                            variant: AppButtonVariant.secondary,
                          ),
                        )
                      : null,
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(managerDeliveriesProvider);
                  await ref.read(managerDeliveriesProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: deliveries.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => DeliveryCard(
                    delivery: deliveries[i],
                    onTap: () => _openDetail(deliveries[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openDetail(Delivery delivery) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DeliveryDetailScreen(
        delivery: delivery,
        onRefresh: () => _refreshDelivery(delivery.id),
      ),
    ));
  }

  Future<Delivery?> _refreshDelivery(int id) async {
    try {
      final provider = managerDeliveryDetailProvider(id);
      return await ref.read(provider.future);
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Filter chips
// ─────────────────────────────────────────────────────────────

class _FilterChips extends ConsumerWidget {
  final ManagerDeliveriesFilter filter;
  const _FilterChips({required this.filter});

  static const _statusGroups = <_StatusGroup>[
    _StatusGroup(
      label: 'All',
      statuses: null,
    ),
    _StatusGroup(
      label: 'Waiting pickup',
      statuses: [DeliveryStatus.paid],
    ),
    _StatusGroup(
      label: 'In transit',
      statuses: [DeliveryStatus.picked_up, DeliveryStatus.dispatched],
    ),
    _StatusGroup(
      label: 'Delivered',
      statuses: [DeliveryStatus.delivered],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final group in _statusGroups) ...[
            ChoiceChip(
              label: Text(group.label),
              selected: _listEquals(filter.statuses, group.statuses),
              onSelected: (_) {
                ref.read(managerDeliveriesFilterProvider.notifier).state =
                    filter.copyWith(statuses: group.statuses);
              },
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  bool _listEquals(List<DeliveryStatus>? a, List<DeliveryStatus>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _StatusGroup {
  final String label;
  final List<DeliveryStatus>? statuses;
  const _StatusGroup({required this.label, required this.statuses});
}