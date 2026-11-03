import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ods_app/features/manager/presentation/providers/manager_dashboard_providers.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/auth/auth_user.dart';
import '../../../../data/models/create_user_input.dart';
import '../providers/manager_branch_providers.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/dashboard_providers.dart';
import '../../../../widgets/widgets.dart';
import '../providers/manager_staff_providers.dart';

/// Create or edit a staff member (Receiver or Rider) in the manager's
/// own branch.
///
/// In edit mode ([initialUser] not null):
///   - Password fields hidden
///   - Role not changeable
///   - Submit sends PUT instead of POST
///
/// The manager's own branch is displayed as context but not editable —
/// the server forces `branch_id` regardless of what the client sends.
class StaffFormScreen extends ConsumerStatefulWidget {
  final AuthUser? initialUser;
  const StaffFormScreen({super.key, this.initialUser});

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  // Rider-only
  final _nidaController = TextEditingController();
  final _dobController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _plateController = TextEditingController();

  String _role = 'receiver';
  bool _dispatcherEnabled = false;
  String _sex = 'male';
  String _vehicleOwnership = 'owned';

  bool _submitting = false;
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;
  final Map<String, String?> _serverErrors = {};

  bool get _isEdit => widget.initialUser != null;

  @override
  void initState() {
    super.initState();
    final u = widget.initialUser;
    if (u != null) {
      _role = u.role;
      _nameController.text = u.name;
      _emailController.text = u.email;
      _phoneController.text = u.phone;
      _dispatcherEnabled = u.dispatcherEnabled;
      _nidaController.text = u.nida ?? '';
      _dobController.text =
          u.dateOfBirth?.toIso8601String().split('T').first ?? '';
      _vehicleTypeController.text = u.vehicleType ?? '';
      _vehicleColorController.text = u.vehicleColor ?? '';
      _sex = u.sex ?? 'male';
      _vehicleOwnership = u.vehicleOwnership ?? 'owned';
      _plateController.text = u.plateNumber ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nidaController.dispose();
    _dobController.dispose();
    _vehicleTypeController.dispose();
    _vehicleColorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    setState(() => _serverErrors.clear());

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _submitting = true);

    final repo = ref.read(staffRepositoryProvider);

    if (_isEdit) {
      final result = await repo.update(
        widget.initialUser!.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        dispatcherEnabled: _role == 'receiver' ? _dispatcherEnabled : null,
        nida: _role == 'rider' ? _nidaController.text.trim() : null,
        sex: _role == 'rider' ? _sex : null,
        dateOfBirth: _role == 'rider' ? _dobController.text.trim() : null,
        vehicleType:
            _role == 'rider' ? _vehicleTypeController.text.trim() : null,
        vehicleColor:
            _role == 'rider' ? _vehicleColorController.text.trim() : null,
        vehicleOwnership: _role == 'rider' ? _vehicleOwnership : null,
        plateNumber: _role == 'rider' ? _plateController.text.trim() : null,
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      result.fold(
        onSuccess: (_) {
          ref.invalidate(managerStaffProvider);
          ref.invalidate(managerStaffDetailProvider(widget.initialUser!.id));
          ref.invalidate(managerDashboardProvider);
          Navigator.of(context).pop();
        },
        onFailure: (failure) => _handleFailure(failure),
      );
    } else {
      final input = CreateUserInput(
        role: _role,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _passwordConfirmController.text,
        // branchId intentionally omitted — server forces it to manager's branch
        dispatcherEnabled: _role == 'receiver' ? _dispatcherEnabled : null,
        nida: _role == 'rider' ? _nidaController.text.trim() : null,
        sex: _role == 'rider' ? _sex : null,
        dateOfBirth: _role == 'rider' ? _dobController.text.trim() : null,
        vehicleType:
            _role == 'rider' ? _vehicleTypeController.text.trim() : null,
        vehicleColor:
            _role == 'rider' ? _vehicleColorController.text.trim() : null,
        vehicleOwnership: _role == 'rider' ? _vehicleOwnership : null,
        plateNumber: _role == 'rider' ? _plateController.text.trim() : null,
      );

      final result = await repo.create(input);

      if (!mounted) return;
      setState(() => _submitting = false);

      result.fold(
        onSuccess: (_) {
          ref.invalidate(managerStaffProvider);
          ref.invalidate(managerDashboardProvider);
          Navigator.of(context).pop();
        },
        onFailure: (failure) => _handleFailure(failure),
      );
    }
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
    // Use the manager-specific provider — /owner/branches/{id} 403s
    // for the Manager role. See 6.6 fixup.
    final branchAsync = ref.watch(managerBranchProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit staff' : 'Add staff'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidate,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              // ─── Branch context banner ──────────────────────
              if (branchAsync.hasValue && branchAsync.value != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.store_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Adding to: ${branchAsync.value!.name} '
                          '(${branchAsync.value!.code})',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ─── Role selector (create mode only) ──────────
              if (!_isEdit) ...[
                Text(
                  'Role',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'receiver', label: Text('Receiver')),
                    ButtonSegment(value: 'rider', label: Text('Rider')),
                  ],
                  selected: {_role},
                  onSelectionChanged: _submitting
                      ? null
                      : (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ─── Common fields ──────────────────────────────
              AppTextField(
                controller: _nameController,
                label: 'Full name',
                prefixIcon: Icons.person_outline,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    _serverErrors['name'] ?? _required(v, 'Full name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
                enabled: !_submitting && !_isEdit,
                textInputAction: TextInputAction.next,
                helperText: _isEdit ? 'Email cannot be changed' : null,
                validator: (v) => _serverErrors['email'] ?? _validateEmail(v),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _phoneController,
                label: 'Phone',
                hint: '0712 345 678',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                validator: (v) => _serverErrors['phone'] ?? _validatePhone(v),
              ),

              // ─── Password (create mode only) ────────────────
              if (!_isEdit) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'At least 8 characters',
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      _serverErrors['password'] ?? _validatePassword(v),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _passwordConfirmController,
                  label: 'Confirm password',
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  enabled: !_submitting,
                  validator: (v) => v != _passwordController.text
                      ? 'Passwords do not match.'
                      : null,
                ),
              ],

              // ─── Receiver-only ──────────────────────────────
              if (_role == 'receiver') ...[
                const SizedBox(height: AppSpacing.md),
                SwitchListTile.adaptive(
                  title: const Text('Dispatcher enabled'),
                  subtitle: const Text(
                    'Allows this receiver to dispatch regional deliveries.',
                  ),
                  value: _dispatcherEnabled,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _dispatcherEnabled = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],

              // ─── Rider-only ─────────────────────────────────
              if (_role == 'rider') ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _nidaController,
                  label: 'NIDA number',
                  hint: '20 digits',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.badge_outlined,
                  enabled: !_submitting,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(20),
                  ],
                  validator: (v) => _serverErrors['nida'] ?? _validateNida(v),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _sex,
                  decoration: const InputDecoration(labelText: 'Sex'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _sex = v ?? _sex),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _dobController,
                  label: 'Date of birth',
                  hint: 'YYYY-MM-DD',
                  prefixIcon: Icons.calendar_today_outlined,
                  enabled: !_submitting,
                  validator: (v) =>
                      _serverErrors['date_of_birth'] ?? _validateDate(v),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _vehicleTypeController,
                  label: 'Vehicle type',
                  hint: 'Motorcycle, Car, Bicycle…',
                  prefixIcon: Icons.two_wheeler_outlined,
                  enabled: !_submitting,
                  validator: (v) =>
                      _serverErrors['vehicle_type'] ??
                      _required(v, 'Vehicle type'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _vehicleColorController,
                  label: 'Vehicle color',
                  hint: 'Red',
                  prefixIcon: Icons.color_lens_outlined,
                  enabled: !_submitting,
                  validator: (v) =>
                      _serverErrors['vehicle_color'] ??
                      _required(v, 'Vehicle color'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _vehicleOwnership,
                  decoration:
                      const InputDecoration(labelText: 'Vehicle ownership'),
                  items: const [
                    DropdownMenuItem(value: 'owned', child: Text('Owned')),
                    DropdownMenuItem(value: 'rented', child: Text('Rented')),
                    DropdownMenuItem(value: 'company', child: Text('Company')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(
                          () => _vehicleOwnership = v ?? _vehicleOwnership),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _plateController,
                  label: 'Plate number',
                  hint: 'T123ABC',
                  prefixIcon: Icons.tag_outlined,
                  enabled: !_submitting,
                  validator: (v) =>
                      _serverErrors['plate_number'] ??
                      _required(v, 'Plate number'),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _isEdit ? 'Save changes' : 'Create staff member',
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

  // ─── Validators ─────────────────────────────────────────────
  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required.' : null;

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$')
        .hasMatch(s)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'[\s\-]'), '');
    if (s.isEmpty) return 'Phone is required.';
    if (!RegExp(r'^(?:\+?255|0)(?:6[1-9]|7[1-9])\d{7}$').hasMatch(s)) {
      return 'Enter a valid Tanzania phone number.';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }

  String? _validateNida(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'NIDA number is required.';
    if (s.length != 20) return 'NIDA number must be exactly 20 digits.';
    return null;
  }

  String? _validateDate(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Date of birth is required.';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
      return 'Use the format YYYY-MM-DD.';
    }
    final parsed = DateTime.tryParse(s);
    if (parsed == null) return 'Enter a valid date.';
    if (!parsed.isBefore(DateTime.now())) return 'Must be in the past.';
    return null;
  }
}
