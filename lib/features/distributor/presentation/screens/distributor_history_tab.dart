import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../widgets/widgets.dart';
import '../../../shared/presentation/screens/delivery_detail_screen.dart';
import '../providers/distributor_history_providers.dart';

/// The Distributor's History tab — full list of own deliveries.
///
/// Status-group chips (All / Active / Delivered / Cancelled) + service
/// type dropdown + search by tracking ID. Tap a card opens the shared
/// `DeliveryDetailScreen`.
class DistributorHistoryTab extends ConsumerStatefulWidget {
  const DistributorHistoryTab({super.key});

  @override
  ConsumerState<DistributorHistoryTab> createState() =>
      _DistributorHistoryTabState();
}

class _DistributorHistoryTabState
    extends ConsumerState<DistributorHistoryTab> {
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
      final current = ref.read(distributorHistoryFilterProvider);
      ref.read(distributorHistoryFilterProvider.notifier).state =
          current.copyWith(
        search: value.trim().isEmpty ? null : value.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(distributorHistoryFilterProvider);
    final deliveriesAsync = ref.watch(distributorHistoryProvider);

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
              _GroupChips(current: filter.group),
              const SizedBox(height: AppSpacing.xs),
              _ServiceTypeDropdown(current: filter.serviceType),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: deliveriesAsync.when(
            loading: () => const LoadingView(message: 'Loading deliveries…'),
            error: (_, __) => ErrorView(
              message: 'Could not load your deliveries.',
              onRetry: () => ref.invalidate(distributorHistoryProvider),
            ),
            data: (deliveries) {
              if (deliveries.isEmpty) {
                final hasFilters = filter.group != DistributorHistoryGroup.all ||
                    filter.serviceType != null ||
                    filter.search != null;
                return EmptyView(
                  title: 'No deliveries',
                  subtitle: hasFilters
                      ? 'Try clearing the filters.'
                      : 'Your delivery history will appear here.',
                  icon: Icons.receipt_long_outlined,
                  action: hasFilters
                      ? AppButton(
                          label: 'Clear filters',
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(distributorHistoryFilterProvider
                                    .notifier)
                                .state = const DistributorHistoryFilter();
                          },
                          variant: AppButtonVariant.secondary,
                        )
                      : null,
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(distributorHistoryProvider);
                  await ref.read(distributorHistoryProvider.future);
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
        onRefresh: () async {
          try {
            return await ref.read(
              distributorDeliveryDetailProvider(delivery.id).future,
            );
          } catch (_) {
            return null;
          }
        },
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────
// Group chips
// ─────────────────────────────────────────────────────────────

class _GroupChips extends ConsumerWidget {
  final DistributorHistoryGroup current;
  const _GroupChips({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final group in DistributorHistoryGroup.values) ...[
            ChoiceChip(
              label: Text(_labelFor(group)),
              selected: current == group,
              onSelected: (_) {
                final f = ref.read(distributorHistoryFilterProvider);
                ref.read(distributorHistoryFilterProvider.notifier).state =
                    f.copyWith(group: group);
              },
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  static String _labelFor(DistributorHistoryGroup g) => switch (g) {
        DistributorHistoryGroup.all => 'All',
        DistributorHistoryGroup.active => 'Active',
        DistributorHistoryGroup.delivered => 'Delivered',
        DistributorHistoryGroup.cancelled => 'Cancelled',
      };
}

// ─────────────────────────────────────────────────────────────
// Service type dropdown
// ─────────────────────────────────────────────────────────────

class _ServiceTypeDropdown extends ConsumerWidget {
  final ServiceType? current;
  const _ServiceTypeDropdown({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<ServiceType?>(
      value: current,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      items: const [
        DropdownMenuItem<ServiceType?>(
          value: null,
          child: Text('All services'),
        ),
        DropdownMenuItem<ServiceType?>(
          value: ServiceType.receive,
          child: Text('Receive'),
        ),
        DropdownMenuItem<ServiceType?>(
          value: ServiceType.send,
          child: Text('Send'),
        ),
        DropdownMenuItem<ServiceType?>(
          value: ServiceType.regional,
          child: Text('Regional'),
        ),
      ],
      onChanged: (value) {
        final f = ref.read(distributorHistoryFilterProvider);
        ref.read(distributorHistoryFilterProvider.notifier).state =
            f.copyWith(serviceType: value);
      },
    );
  }
}