import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ods_app/features/owner/presentation/providers/owner_branch_providers.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/auth/auth_user.dart';
import '../../../../data/models/branch.dart';
import '../../../../data/models/create_user_input.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_user_providers.dart';
import '../../../../shared/providers/dashboard_providers.dart';
import '../../../../data/models/branch.dart';
/// Create a new user (Manager / Receiver / Rider).
///
/// Role-conditional field display:
///   Manager  → branch picker only
///   Receiver → branch picker + dispatcher toggle
///   Rider    → branch picker + NIDA + sex + DOB + vehicle fields
///
/// Distributors are NOT created here — they self-register and are
/// approved from the detail screen. Owners cannot be created (singleton).
class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
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

  String _role = 'manager';
  int? _branchId;
  bool _dispatcherEnabled = false;
  String _sex = 'male';
  String _vehicleOwnership = 'owned';

  bool _submitting = false;
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;
  final Map<String, String?> _serverErrors = {};

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

    if (_branchId == null) {
      _showSnack('Please select a branch.', isError: true);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _submitting = true);

    final input = CreateUserInput(
      role: _role,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      passwordConfirmation: _passwordConfirmController.text,
      branchId: _branchId!,
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

    final repo = ref.read(userRepositoryProvider);
    final result = await repo.create(input);

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      onSuccess: (user) {
        // Refresh the users list, the branch-manager picker (so a new
        // Manager appears immediately in 5.5's assign-manager sheet),
        // and the dashboard KPIs (which count users by role).
        ref.invalidate(ownerUsersProvider);
        ref.invalidate(availableManagersProvider);
        ref.invalidate(ownerDashboardProvider);

        Navigator.of(context).pop();
        _showSnack('${_roleLabel(_role)} created: ${user.name}');
      },
      onFailure: (failure) {
        if (failure.fieldErrors.isNotEmpty) {
          setState(() {
            for (final e in failure.fieldErrors.entries) {
              _serverErrors[e.key] = e.value.isEmpty ? null : e.value.first;
            }
            _autoValidate = AutovalidateMode.onUserInteraction;
          });
          _formKey.currentState?.validate();
        } else {
          _showSnack(failure.message, isError: true);
        }
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(ownerBranchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add user')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidate,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              // ─── Role selector ──────────────────────────────
              Text(
                'Role',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'manager', label: Text('Manager')),
                  ButtonSegment(value: 'receiver', label: Text('Receiver')),
                  ButtonSegment(value: 'rider', label: Text('Rider')),
                ],
                selected: {_role},
                onSelectionChanged: _submitting
                    ? null
                    : (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── Common fields ──────────────────────────────
              AppTextField(
                controller: _nameController,
                label: 'Full name',
                prefixIcon: Icons.person_outline,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    _serverErrors['name'] ??
                    _required(v, 'Full name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    _serverErrors['email'] ?? _validateEmail(v),
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
                validator: (v) =>
                    _serverErrors['phone'] ?? _validatePhone(v),
              ),
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
              const SizedBox(height: AppSpacing.md),

              // ─── Branch picker ──────────────────────────────
              Text(
                'Branch',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              branchesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(
                  'Could not load branches.',
                  style: TextStyle(color: AppColors.error),
                ),
                data: (branches) => DropdownButtonFormField<int>(
                  value: _branchId,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: branches
                      .where((b) => b.isActive)
                      .map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text('${b.name} (${b.code})'),
                          ))
                      .toList(growable: false),
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _branchId = v),
                  validator: (v) => v == null ? 'Branch is required.' : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── Receiver-only ──────────────────────────────
              if (_role == 'receiver') ...[
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
                const SizedBox(height: AppSpacing.sm),
              ],

              // ─── Rider-only ─────────────────────────────────
              if (_role == 'rider') ...[
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
                  validator: (v) =>
                      _serverErrors['nida'] ?? _validateNida(v),
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
                  validator: (v) => _serverErrors['date_of_birth'] ??
                      _validateDate(v),
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
                label: 'Create user',
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

  // ─── Helpers ────────────────────────────────────────────────
  String _roleLabel(String role) => switch (role) {
        'manager' => 'Manager',
        'receiver' => 'Receiver',
        'rider' => 'Rider',
        _ => 'User',
      };

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