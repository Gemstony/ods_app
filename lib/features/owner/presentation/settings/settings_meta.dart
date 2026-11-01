/// Flutter-side description of how to render and validate each setting.
///
/// The authoritative source of truth for validation rules is the
/// backend's `SettingsSchema` (5.3). This file mirrors it for UI
/// purposes: how to display, what input type, what range. Adding a new
/// setting requires one entry here plus one in the backend schema — the
/// two files stay in sync by convention.
///
/// Any setting NOT in this map is silently skipped by the settings UI
/// (with a DevTools warning) — adding it here makes it appear.
class SettingMeta {
  final String label;
  final SettingInputType type;
  final String? unit;
  final String? hint;
  final num? min;
  final num? max;

  /// For `dropdown` and `chipList` types: the set of allowed values.
  final List<String>? options;

  const SettingMeta({
    required this.label,
    required this.type,
    this.unit,
    this.hint,
    this.min,
    this.max,
    this.options,
  });
}

enum SettingInputType {
  number,   // decimal
  integer,
  bool,
  text,
  dropdown, // single choice from `options`
  chipList, // multi-select from `options`
}

/// Every setting the Owner can edit through the settings UI.
///
/// Keys match the backend `SettingsSchema` exactly.
const Map<String, SettingMeta> settingsMeta = {
  // ─── Location ────────────────────────────────────────────
  'location.pickup_radius_km': SettingMeta(
    label: 'Pickup radius',
    type: SettingInputType.number,
    unit: 'km',
    min: 0,
    max: 500,
    hint: 'Maximum distance to consider a rider for pickup',
  ),
  'location.location_freshness_minutes': SettingMeta(
    label: 'Location freshness',
    type: SettingInputType.integer,
    unit: 'minutes',
    min: 0,
    max: 120,
    hint: 'How old a rider location can be before it counts as stale',
  ),
  'location.assignment_timeout_minutes': SettingMeta(
    label: 'Assignment timeout',
    type: SettingInputType.integer,
    unit: 'minutes',
    min: 1,
    max: 60,
    hint: 'How long a rider has to accept an assignment',
  ),

  // ─── Batching ────────────────────────────────────────────
  'batching.window_minutes': SettingMeta(
    label: 'Batching window',
    type: SettingInputType.integer,
    unit: 'minutes',
    min: 1,
    max: 120,
    hint: 'Window for grouping regional deliveries',
  ),
  'batching.early_closure_minutes': SettingMeta(
    label: 'Early closure',
    type: SettingInputType.integer,
    unit: 'minutes',
    min: 0,
    max: 60,
    hint: 'Close a batch early if no new orders arrive',
  ),
  'batching.max_batch_size': SettingMeta(
    label: 'Max batch size',
    type: SettingInputType.integer,
    min: 1,
    max: 100,
    hint: 'Maximum number of deliveries per batch',
  ),

  // ─── Finance ─────────────────────────────────────────────
  'finance.payout_schedule': SettingMeta(
    label: 'Payout schedule',
    type: SettingInputType.dropdown,
    options: ['daily', 'weekly', 'biweekly', 'monthly'],
  ),
  'finance.payout_day': SettingMeta(
    label: 'Payout day',
    type: SettingInputType.dropdown,
    options: [
      'monday', 'tuesday', 'wednesday', 'thursday',
      'friday', 'saturday', 'sunday',
    ],
  ),
  'finance.expense_categories': SettingMeta(
    label: 'Expense categories',
    type: SettingInputType.chipList,
    options: [
      'fuel', 'salary', 'rent', 'utilities',
      'supplies', 'maintenance', 'transport_provider', 'other',
    ],
  ),

  // ─── Payments ────────────────────────────────────────────
  'payments.enabled_methods': SettingMeta(
    label: 'Payment methods',
    type: SettingInputType.chipList,
    options: ['clickpesa', 'cash', 'manual'],
  ),
  'payments.refund_window_hours': SettingMeta(
    label: 'Refund window',
    type: SettingInputType.integer,
    unit: 'hours',
    min: 0,
    max: 720,
    hint: 'Time during which a payment can be refunded',
  ),
  'payments.max_manual_refund_tsh': SettingMeta(
    label: 'Max manual refund',
    type: SettingInputType.integer,
    unit: 'TZS',
    min: 0,
    max: 10000000,
    hint: 'Largest manual refund a Manager can approve',
  ),

  // ─── Security ────────────────────────────────────────────
  'security.verification_required_pickup': SettingMeta(
    label: 'Require code at pickup',
    type: SettingInputType.bool,
    hint: 'DISTRIBUTOR_CODE must be entered at pickup',
  ),
  'security.verification_required_delivery': SettingMeta(
    label: 'Require code at delivery',
    type: SettingInputType.bool,
    hint: 'RECIPIENT_CODE must be entered at delivery',
  ),
  'security.max_verification_attempts': SettingMeta(
    label: 'Max code attempts',
    type: SettingInputType.integer,
    min: 1,
    max: 10,
    hint: 'Wrong-code attempts before code expires',
  ),
  'security.verification_code_ttl_hours': SettingMeta(
    label: 'Code validity',
    type: SettingInputType.integer,
    unit: 'hours',
    min: 1,
    max: 720,
    hint: 'How long a verification code remains valid',
  ),

  // ─── Notifications ───────────────────────────────────────
  'notifications.sms_enabled': SettingMeta(
    label: 'SMS notifications',
    type: SettingInputType.bool,
    hint: 'Send SMS via Beem Africa',
  ),
  'notifications.push_enabled': SettingMeta(
    label: 'Push notifications',
    type: SettingInputType.bool,
    hint: 'Send push via FCM',
  ),
  'notifications.email_enabled': SettingMeta(
    label: 'Email notifications',
    type: SettingInputType.bool,
    hint: 'Send email notifications',
  ),

  // ─── App ─────────────────────────────────────────────────
  'app.min_supported_version': SettingMeta(
    label: 'Minimum app version',
    type: SettingInputType.text,
    hint: 'Clients older than this must upgrade (e.g. 0.1.0)',
  ),
  'app.maintenance_mode': SettingMeta(
    label: 'Maintenance mode',
    type: SettingInputType.bool,
    hint: 'Clients see a maintenance screen',
  ),
  'app.app_name': SettingMeta(
    label: 'App name',
    type: SettingInputType.text,
    hint: 'Displayed throughout the app',
  ),
};

/// Human-readable label for a category key.
String categoryLabel(String category) => switch (category) {
      'location' => 'Location',
      'batching' => 'Batching',
      'finance' => 'Finance',
      'payments' => 'Payments',
      'security' => 'Security',
      'notifications' => 'Notifications',
      'app' => 'App',
      _ => category[0].toUpperCase() + category.substring(1),
    };

/// Icon for a category key.
int _iconCodeFor(String category) => 0; // reserved — icons defined in UI

/// Human-readable label for an option value.
String optionLabel(String value) =>
    value.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');