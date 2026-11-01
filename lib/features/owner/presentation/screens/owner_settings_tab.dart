import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/models/pricing_config.dart';
import '../../../../data/models/setting.dart';
import '../../../../shared/providers/dashboard_providers.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_settings_providers.dart';
import '../settings/settings_meta.dart';
import 'pricing_config_screen.dart';

/// Owner-facing settings configuration.
///
/// Layout:
///   - Pricing-config preview card (tap → full-screen editor)
///   - One section per settings category (Location, Batching, …)
///   - Sticky save bar at bottom when any value has changed
class OwnerSettingsTab extends ConsumerStatefulWidget {
  const OwnerSettingsTab({super.key});

  @override
  ConsumerState<OwnerSettingsTab> createState() => _OwnerSettingsTabState();
}

class _OwnerSettingsTabState extends ConsumerState<OwnerSettingsTab> {
  bool _initialized = false;
  bool _saving = false;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _pendingChanges = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── State initialization ────────────────────────────────
  void _ensureInitialized(Map<String, List<Setting>> grouped) {
    if (_initialized) return;
    _initialized = true;
    for (final settings in grouped.values) {
      for (final s in settings) {
        final meta = settingsMeta[s.key];
        if (meta == null) continue;
        if (_needsController(meta.type)) {
          _controllers[s.key] = TextEditingController(
            text: _formatForDisplay(s.value, meta),
          );
        }
      }
    }
  }

  bool _needsController(SettingInputType type) =>
      type == SettingInputType.number ||
      type == SettingInputType.integer ||
      type == SettingInputType.text;

  String _formatForDisplay(dynamic value, SettingMeta meta) {
    if (value == null) return '';
    if (meta.type == SettingInputType.integer) {
      return value is int ? value.toString() : value.toString();
    }
    if (meta.type == SettingInputType.number) {
      final d = value is num ? value.toDouble() : double.tryParse(value.toString());
      if (d == null) return value.toString();
      return d == d.truncateToDouble() ? d.toStringAsFixed(0) : d.toString();
    }
    return value.toString();
  }

  // ─── Change handlers ─────────────────────────────────────
  void _onFieldChanged(String key, dynamic newValue, dynamic originalValue) {
    setState(() {
      if (_valuesEqual(newValue, originalValue)) {
        _pendingChanges.remove(key);
      } else {
        _pendingChanges[key] = newValue;
      }
    });
  }

  void _onDiscard() {
    setState(() {
      _pendingChanges.clear();
      // Reset controllers back to loaded values
      final settingsAsync = ref.read(ownerSettingsProvider);
      final grouped = settingsAsync.valueOrNull;
      if (grouped == null) return;
      for (final settings in grouped.values) {
        for (final s in settings) {
          final meta = settingsMeta[s.key];
          if (meta == null) continue;
          if (_needsController(meta.type)) {
            _controllers[s.key]?.text = _formatForDisplay(s.value, meta);
          }
        }
      }
    });
  }

  Future<void> _onSave() async {
    if (_pendingChanges.isEmpty) return;
    setState(() => _saving = true);

    final repo = ref.read(settingsRepositoryProvider);
    final result = await repo.bulkUpdate(_pendingChanges.entries.toList());

    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      onSuccess: (_) {
        setState(() => _pendingChanges.clear());
        ref.invalidate(ownerSettingsProvider);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Settings saved.')));
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.error,
          ));
      },
    );
  }

  // ─── Value comparison ────────────────────────────────────
  bool _valuesEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a is num && b is num) {
      return (a.toDouble() - b.toDouble()).abs() < 0.0001;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      final setA = a.map((e) => e.toString()).toSet();
      final setB = b.map((e) => e.toString()).toSet();
      return setA.difference(setB).isEmpty && setB.difference(setA).isEmpty;
    }
    return a == b;
  }

  // ─── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(ownerSettingsProvider);
    final pricingAsync = ref.watch(ownerPricingConfigProvider);

    return settingsAsync.when(
      loading: () => const LoadingView(message: 'Loading settings…'),
      error: (_, __) => ErrorView(
        message: 'Could not load settings.',
        onRetry: () => ref.invalidate(ownerSettingsProvider),
      ),
      data: (grouped) {
        _ensureInitialized(grouped);
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ownerSettingsProvider);
                  ref.invalidate(ownerPricingConfigProvider);
                  await ref.read(ownerSettingsProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _PricingConfigCard(
                      config: pricingAsync.valueOrNull,
                      onTap: () => _openPricingConfig(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ..._buildCategorySections(grouped),
                  ],
                ),
              ),
            ),
            if (_pendingChanges.isNotEmpty) _buildSaveBar(),
          ],
        );
      },
    );
  }

  List<Widget> _buildCategorySections(Map<String, List<Setting>> grouped) {
    final categories = grouped.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final category in categories) {
      final items = grouped[category]!
          .where((s) => settingsMeta.containsKey(s.key))
          .toList();
      if (items.isEmpty) continue;
      widgets.add(_CategorySection(
        category: category,
        settings: items,
        buildSetting: _buildSettingWidget,
      ));
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    return widgets;
  }

  Widget _buildSettingWidget(Setting setting) {
    final meta = settingsMeta[setting.key];
    if (meta == null) {
      AppLogger.w('No SettingMeta for key: ${setting.key}');
      return const SizedBox.shrink();
    }

    final original = setting.value;
    final current = _pendingChanges.containsKey(setting.key)
        ? _pendingChanges[setting.key]
        : original;

    switch (meta.type) {
      case SettingInputType.bool:
        return _BooleanSetting(
          meta: meta,
          value: current as bool? ?? false,
          onChanged: (v) => _onFieldChanged(setting.key, v, original),
        );
      case SettingInputType.dropdown:
        return _DropdownSetting(
          meta: meta,
          value: current as String? ?? '',
          onChanged: (v) => _onFieldChanged(setting.key, v, original),
        );
      case SettingInputType.chipList:
        return _ChipListSetting(
          meta: meta,
          values: (current as List).cast<String>().toSet(),
          onChanged: (v) => _onFieldChanged(setting.key, v.toList(), original),
        );
      case SettingInputType.number:
      case SettingInputType.integer:
      case SettingInputType.text:
        return _TextSetting(
          meta: meta,
          controller: _controllers[setting.key]!,
          onChanged: (text) {
            final parsed = _parseValue(text, meta);
            _onFieldChanged(setting.key, parsed, original);
          },
        );
    }
  }

  dynamic _parseValue(String text, SettingMeta meta) {
    if (meta.type == SettingInputType.text) return text;
    if (meta.type == SettingInputType.integer) return int.tryParse(text);
    if (meta.type == SettingInputType.number) return double.tryParse(text);
    return text;
  }

  Widget _buildSaveBar() {
    final count = _pendingChanges.length;
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$count unsaved change${count == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              TextButton(
                onPressed: _saving ? null : _onDiscard,
                child: const Text('Discard'),
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: 120,
                child: AppButton(
                  label: 'Save',
                  onPressed: _saving ? null : _onSave,
                  isLoading: _saving,
                  size: AppButtonSize.small,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPricingConfig(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const PricingConfigScreen(),
    ));
  }
}

// ─────────────────────────────────────────────────────────────
// Pricing config preview card
// ─────────────────────────────────────────────────────────────

class _PricingConfigCard extends StatelessWidget {
  final PricingConfig? config;
  final VoidCallback onTap;

  const _PricingConfigCard({required this.config, required this.onTap});

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
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.price_change_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pricing configuration',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config == null
                          ? 'Tap to edit'
                          : 'TZS ${config!.localRatePerKm.toStringAsFixed(0)}/km · '
                              'Rider ${config!.riderBaselinePercent.toStringAsFixed(0)}%'
                              '+${config!.riderBonusPercent.toStringAsFixed(0)}%',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.onSurfaceSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Category section
// ─────────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String category;
  final List<Setting> settings;
  final Widget Function(Setting) buildSetting;

  const _CategorySection({
    required this.category,
    required this.settings,
    required this.buildSetting,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            categoryLabel(category),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < settings.length; i++) ...[
                buildSetting(settings[i]),
                if (i < settings.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Individual setting widgets
// ─────────────────────────────────────────────────────────────

class _TextSetting extends StatelessWidget {
  final SettingMeta meta;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _TextSetting({
    required this.meta,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isNumeric = meta.type != SettingInputType.text;
    return AppTextField(
      controller: controller,
      label: meta.unit == null ? meta.label : '${meta.label} (${meta.unit})',
      hint: meta.hint,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: false)
          : TextInputType.text,
      inputFormatters: isNumeric
          ? [
              FilteringTextInputFormatter.allow(
                meta.type == SettingInputType.integer
                    ? RegExp(r'\d')
                    : RegExp(r'[\d.]'),
              ),
            ]
          : null,
      onChanged: onChanged,
    );
  }
}

class _BooleanSetting extends StatelessWidget {
  final SettingMeta meta;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BooleanSetting({
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meta.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (meta.hint != null)
                Text(
                  meta.hint!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                ),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _DropdownSetting extends StatelessWidget {
  final SettingMeta meta;
  final String value;
  final ValueChanged<String> onChanged;

  const _DropdownSetting({
    required this.meta,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          meta.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        DropdownButtonFormField<String>(
          value: meta.options?.contains(value) == true ? value : null,
          decoration: const InputDecoration(),
          items: meta.options
                  ?.map((o) =>
                      DropdownMenuItem(value: o, child: Text(optionLabel(o))))
                  .toList() ??
              const [],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class _ChipListSetting extends StatelessWidget {
  final SettingMeta meta;
  final Set<String> values;
  final ValueChanged<Set<String>> onChanged;

  const _ChipListSetting({
    required this.meta,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          meta.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (meta.hint != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            meta.hint!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: (meta.options ?? const [])
              .map((o) => FilterChip(
                    label: Text(optionLabel(o)),
                    selected: values.contains(o),
                    onSelected: (sel) {
                      final newSet = Set<String>.from(values);
                      if (sel) {
                        newSet.add(o);
                      } else {
                        newSet.remove(o);
                      }
                      onChanged(newSet);
                    },
                  ))
              .toList(growable: false),
        ),
      ],
    );
  }
}