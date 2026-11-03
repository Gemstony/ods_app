import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../data/models/delivery.dart';
import '../../../../../data/models/delivery_input.dart';
import '../../../../../shared/providers/auth_provider.dart';
import '../../../../../widgets/widgets.dart';
import '../widgets/wizard_bottom_bar.dart';

/// Step 2: enter order details.
///
/// Two modes (per the ODS doc):
///   - M-Commerce (EXGO Order IDs)
///   - WhatsApp orders (product table: name / code / quantity)
///
/// Also captures the pickup-side contact phone.
class OrderDetailsStep extends ConsumerStatefulWidget {
  final ServiceType serviceType;
  final void Function({
    required List<DeliveryItemInput> items,
    required String pickupContactPhone,
  }) onSubmitted;
  final VoidCallback onBack;

  const OrderDetailsStep({
    super.key,
    required this.serviceType,
    required this.onSubmitted,
    required this.onBack,
  });

  @override
  ConsumerState<OrderDetailsStep> createState() => _OrderDetailsStepState();
}

class _OrderDetailsStepState extends ConsumerState<OrderDetailsStep> {
  String _mode = 'exgo'; // 'exgo' | 'whatsapp'
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  // EXGO mode — one controller per order ID row.
  final List<TextEditingController> _exgoControllers = [
    TextEditingController()
  ];

  // WhatsApp mode — one row per product.
  final List<_WhatsappRow> _whatsappRows = [_WhatsappRow()];

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _exgoControllers) {
      c.dispose();
    }
    for (final r in _whatsappRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addExgoRow() {
    if (_exgoControllers.length >= 20) return;
    setState(() => _exgoControllers.add(TextEditingController()));
  }

  void _removeExgoRow(int i) {
    if (_exgoControllers.length <= 1) return;
    setState(() {
      _exgoControllers[i].dispose();
      _exgoControllers.removeAt(i);
    });
  }

  void _addWhatsappRow() {
    if (_whatsappRows.length >= 20) return;
    setState(() => _whatsappRows.add(_WhatsappRow()));
  }

  void _removeWhatsappRow(int i) {
    if (_whatsappRows.length <= 1) return;
    setState(() {
      _whatsappRows[i].dispose();
      _whatsappRows.removeAt(i);
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    final items = _mode == 'exgo'
        ? _buildExgoItems()
        : _buildWhatsappItems();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('Add at least one valid item.'),
        ));
      return;
    }

    widget.onSubmitted(
      items: items,
      pickupContactPhone: _phoneController.text.trim(),
    );
  }

  List<DeliveryItemInput> _buildExgoItems() {
    return _exgoControllers
        .map((c) => c.text.trim())
        .where((id) => id.isNotEmpty)
        .map((id) => DeliveryItemInput(exgoOrderId: id))
        .toList(growable: false);
  }

  List<DeliveryItemInput> _buildWhatsappItems() {
    return _whatsappRows
        .map((r) => r.toItem())
        .whereType<DeliveryItemInput>()
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _autoValidate,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              children: [
                // ─── Mode toggle ─────────────────────────────
                Text(
                  'How did you place this order?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'exgo',
                      label: Text('M-Commerce'),
                      icon: Icon(Icons.cloud_outlined),
                    ),
                    ButtonSegment(
                      value: 'whatsapp',
                      label: Text('WhatsApp'),
                      icon: Icon(Icons.chat_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) =>
                      setState(() => _mode = s.first),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ─── Mode-specific input ─────────────────────
                if (_mode == 'exgo')
                  _buildExgoSection()
                else
                  _buildWhatsappSection(),

                const SizedBox(height: AppSpacing.lg),

                // ─── Contact phone ───────────────────────────
                Text(
                  'Pickup contact phone',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  hint: '0712 345 678',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  helperText:
                      'Used by the branch and rider to reach you at pickup.',
                  validator: (v) => Validators.phone(v),
                ),
              ],
            ),
          ),
          WizardBottomBar(
            onBack: widget.onBack,
            nextLabel: 'Next',
            onNext: _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildExgoSection() {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'EXGO Order IDs',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _addExgoRow,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add another'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Enter one order ID per row. Add multiple if this delivery '
          'includes more than one order.',
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _exgoControllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _exgoControllers[i],
                    label: 'Order ID ${i + 1}',
                    hint: 'EXGO-12345',
                    prefixIcon: Icons.receipt_long_outlined,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty && _exgoControllers.length == 1) {
                        return 'Enter an order ID.';
                      }
                      return null;
                    },
                  ),
                ),
                if (_exgoControllers.length > 1)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => _removeExgoRow(i),
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWhatsappSection() {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Products',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _addWhatsappRow,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add product'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Enter each product with its code and quantity.',
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < _whatsappRows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Product ${i + 1}',
                        style: text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                      const Spacer(),
                      if (_whatsappRows.length > 1)
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => _removeWhatsappRow(i),
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.error,
                          ),
                        ),
                    ],
                  ),
                  AppTextField(
                    controller: _whatsappRows[i].name,
                    label: 'Product name',
                    hint: 'Salmon Oil',
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      return s.isEmpty ? 'Product name is required.' : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _whatsappRows[i].code,
                          label: 'Product code',
                          hint: 'SLM-001',
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            return s.isEmpty
                                ? 'Product code is required.'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      SizedBox(
                        width: 90,
                        child: AppTextField(
                          controller: _whatsappRows[i].quantity,
                          label: 'Qty',
                          hint: '1',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 1) {
                              return 'Qty?';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WhatsappRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController code = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');

  DeliveryItemInput? toItem() {
    final n = name.text.trim();
    final c = code.text.trim();
    final q = int.tryParse(quantity.text.trim());
    if (n.isEmpty || c.isEmpty || q == null || q < 1) return null;
    return DeliveryItemInput(
      productName: n,
      productCode: c,
      quantity: q,
    );
  }

  void dispose() {
    name.dispose();
    code.dispose();
    quantity.dispose();
  }
}