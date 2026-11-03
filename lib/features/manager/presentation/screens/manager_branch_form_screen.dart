import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/branch.dart';
import '../../../../shared/providers/branch_providers.dart';
import '../../../../shared/providers/dashboard_providers.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';
import '../providers/manager_branch_providers.dart';
import '../providers/manager_dashboard_providers.dart';

/// Manager-specific edit form for their own branch.
///
/// Only name, address, latitude, and longitude are editable. Code and
/// status are intentionally omitted — those are Owner-only (see 6.1's
/// `UpdateBranchRequest`). Operating hours are preserved from the
/// initial branch — no hours editor yet (deferred to a polish pass).
class ManagerBranchFormScreen extends ConsumerStatefulWidget {
  final Branch initialBranch;
  const ManagerBranchFormScreen({super.key, required this.initialBranch});

  @override
  ConsumerState<ManagerBranchFormScreen> createState() =>
      _ManagerBranchFormScreenState();
}

class _ManagerBranchFormScreenState
    extends ConsumerState<ManagerBranchFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  bool _submitting = false;
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;
  final Map<String, String?> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    final b = widget.initialBranch;
    _nameController = TextEditingController(text: b.name);
    _addressController = TextEditingController(text: b.address);
    _latController = TextEditingController(text: b.latitude.toString());
    _lngController = TextEditingController(text: b.longitude.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    setState(() => _serverErrors.clear());

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _submitting = true);

    final repo = ref.read(branchRepositoryProvider);
    final result = await repo.updateMyBranch(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      latitude: double.tryParse(_latController.text.trim()) ?? 0,
      longitude: double.tryParse(_lngController.text.trim()) ?? 0,
      operatingHours: widget.initialBranch.operatingHours,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      onSuccess: (_) {
        // Invalidate all three caches that hold branch data:
        //   - managerBranchProvider (used by Profile tab)
        //   - currentBranchProvider (used by staff form banner)
        //   - managerDashboardProvider (Home tab shows branch name)
        ref.invalidate(managerBranchProvider);
        ref.invalidate(currentBranchProvider);
        ref.invalidate(managerDashboardProvider);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branch updated.')),
        );
      },
      onFailure: (failure) => _handleFailure(failure),
    );
  }

  void _handleFailure(Failure failure) {
    if (failure.fieldErrors.isNotEmpty) {
      setState(() {
        for (final e in failure.fieldErrors.entries) {
          _serverErrors[e.key] = e.value.isEmpty ? null : e.value.first;
        }
        _autoValidate = AutovalidateMode.onUserInteraction;
      });
      _formKey.currentState?.validate();
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.error,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit branch')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidate,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              // ─── Locked fields ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _lockedField(context, 'Code', widget.initialBranch.code),
                    const SizedBox(height: AppSpacing.xxs),
                    _lockedField(
                      context,
                      'Status',
                      widget.initialBranch.isActive ? 'Active' : 'Inactive',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── Editable fields ────────────────────────────
              AppTextField(
                controller: _nameController,
                label: 'Branch name',
                prefixIcon: Icons.store_outlined,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    _serverErrors['name'] ?? _required(v, 'Branch name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _addressController,
                label: 'Address',
                prefixIcon: Icons.location_on_outlined,
                enabled: !_submitting,
                maxLines: 2,
                validator: (v) =>
                    _serverErrors['address'] ?? _required(v, 'Address'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _latController,
                      label: 'Latitude',
                      hint: '-6.7924',
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      prefixIcon: Icons.my_location_outlined,
                      enabled: !_submitting,
                      validator: (v) =>
                          _serverErrors['latitude'] ?? _validateLat(v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      controller: _lngController,
                      label: 'Longitude',
                      hint: '39.2083',
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      prefixIcon: Icons.explore_outlined,
                      enabled: !_submitting,
                      validator: (v) =>
                          _serverErrors['longitude'] ?? _validateLng(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save changes',
                onPressed: _onSubmit,
                isLoading: _submitting,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lockedField(BuildContext context, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ),
        Text(
          'Locked',
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceSubtle,
            fontStyle: FontStyle.italic,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required.' : null;

  String? _validateLat(String? v) {
    final d = double.tryParse(v?.trim() ?? '');
    if (d == null) return 'Latitude is required.';
    if (d < -90 || d > 90) return 'Must be between -90 and 90.';
    return null;
  }

  String? _validateLng(String? v) {
    final d = double.tryParse(v?.trim() ?? '');
    if (d == null) return 'Longitude is required.';
    if (d < -180 || d > 180) return 'Must be between -180 and 180.';
    return null;
  }
}