import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_branch_providers.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/branch.dart';
import '../../../../data/models/branch_input.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';


/// Full-screen create / edit form for a branch.
///
/// Pass `initialBranch` to enter edit mode; leave null to create.
///
/// Operating hours are set to a sensible default on create (Mon–Sat
/// 08:00–18:00, Sun closed) and preserved on edit. A dedicated editor
/// is deferred to a later phase.
class BranchFormScreen extends ConsumerStatefulWidget {
  final Branch? initialBranch;
  const BranchFormScreen({super.key, this.initialBranch});

  @override
  ConsumerState<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends ConsumerState<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _addressController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  late BranchStatus _status;
  bool _submitting = false;
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  final Map<String, String?> _serverErrors = {};

  bool get _isEdit => widget.initialBranch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.initialBranch;
    _nameController = TextEditingController(text: b?.name ?? '');
    _codeController = TextEditingController(text: b?.code ?? '');
    _addressController = TextEditingController(text: b?.address ?? '');
    _latController =
        TextEditingController(text: b?.latitude.toString() ?? '');
    _lngController =
        TextEditingController(text: b?.longitude.toString() ?? '');
    _status = b?.status ?? BranchStatus.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
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

    final input = BranchInput(
      name: _nameController.text.trim(),
      code: _codeController.text.trim().toUpperCase(),
      address: _addressController.text.trim(),
      latitude: double.tryParse(_latController.text.trim()) ?? 0,
      longitude: double.tryParse(_lngController.text.trim()) ?? 0,
      operatingHours: widget.initialBranch?.operatingHours ??
          _defaultOperatingHours(),
      status: _status,
    );

    final repo = ref.read(branchRepositoryProvider);
    final result = _isEdit
        ? await repo.update(widget.initialBranch!.id, input)
        : await repo.create(input);

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      onSuccess: (_) {
        ref.invalidate(ownerBranchesProvider);
        if (_isEdit) {
          ref.invalidate(ownerBranchProvider(widget.initialBranch!.id));
        }
        Navigator.of(context).pop();
      },
      onFailure: (Failure failure) {
        if (failure.fieldErrors.isNotEmpty) {
          setState(() {
            for (final entry in failure.fieldErrors.entries) {
              _serverErrors[entry.key] =
                  entry.value.isEmpty ? null : entry.value.first;
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
      },
    );
  }

  Map<String, dynamic> _defaultOperatingHours() => {
        'monday': {'open': '08:00', 'close': '18:00'},
        'tuesday': {'open': '08:00', 'close': '18:00'},
        'wednesday': {'open': '08:00', 'close': '18:00'},
        'thursday': {'open': '08:00', 'close': '18:00'},
        'friday': {'open': '08:00', 'close': '18:00'},
        'saturday': {'open': '08:00', 'close': '14:00'},
        'sunday': null,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit branch' : 'New branch'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidate,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Branch name',
                hint: 'e.g. Dar es Salaam Central',
                prefixIcon: Icons.store_outlined,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    _serverErrors['name'] ??
                    _required(v, 'Branch name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _codeController,
                label: 'Code',
                hint: 'e.g. DSM-01',
                prefixIcon: Icons.tag_outlined,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                ],
                validator: (v) =>
                    _serverErrors['code'] ?? _validateCode(v),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _addressController,
                label: 'Address',
                hint: 'Street, area, city',
                prefixIcon: Icons.location_on_outlined,
                enabled: !_submitting,
                maxLines: 2,
                validator: (v) =>
                    _serverErrors['address'] ??
                    _required(v, 'Address'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _latController,
                      label: 'Latitude',
                      hint: '-6.7924',
                      prefixIcon: Icons.my_location_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      enabled: !_submitting,
                      validator: (v) =>
                          _serverErrors['latitude'] ??
                          _validateLat(v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      controller: _lngController,
                      label: 'Longitude',
                      hint: '39.2083',
                      prefixIcon: Icons.explore_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      enabled: !_submitting,
                      validator: (v) =>
                          _serverErrors['longitude'] ??
                          _validateLng(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<BranchStatus>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: BranchStatus.active,
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: BranchStatus.inactive,
                    child: Text('Inactive'),
                  ),
                ],
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _isEdit ? 'Save changes' : 'Create branch',
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

  // ─── Validators ──────────────────────────────────────────
  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required.' : null;

  String? _validateCode(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Code is required.';
    if (s.length < 2) return 'Code must be at least 2 characters.';
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(s)) {
      return 'Code may only contain letters, numbers, and hyphens.';
    }
    return null;
  }

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