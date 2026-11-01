import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/features/owner/presentation/settings/settings_meta.dart';

void main() {
  group('settingsMeta', () {
    test('has a meta entry for every documented setting', () {
      const expectedKeys = [
        'location.pickup_radius_km',
        'location.location_freshness_minutes',
        'location.assignment_timeout_minutes',
        'batching.window_minutes',
        'batching.early_closure_minutes',
        'batching.max_batch_size',
        'finance.payout_schedule',
        'finance.payout_day',
        'finance.expense_categories',
        'payments.enabled_methods',
        'payments.refund_window_hours',
        'payments.max_manual_refund_tsh',
        'security.verification_required_pickup',
        'security.verification_required_delivery',
        'security.max_verification_attempts',
        'security.verification_code_ttl_hours',
        'notifications.sms_enabled',
        'notifications.push_enabled',
        'notifications.email_enabled',
        'app.min_supported_version',
        'app.maintenance_mode',
        'app.app_name',
      ];
      for (final key in expectedKeys) {
        expect(settingsMeta.containsKey(key), isTrue,
            reason: 'Missing meta for $key');
      }
    });

    test('every meta has a label and type', () {
      settingsMeta.forEach((key, meta) {
        expect(meta.label.isNotEmpty, isTrue, reason: '$key missing label');
      });
    });

    test('dropdown and chipList types have options', () {
      settingsMeta.forEach((key, meta) {
        if (meta.type == SettingInputType.dropdown ||
            meta.type == SettingInputType.chipList) {
          expect(meta.options, isNotNull,
              reason: '$key with type ${meta.type} has no options');
          expect(meta.options!.isNotEmpty, isTrue,
              reason: '$key has empty options list');
        }
      });
    });

    test('payments.enabled_methods offers the three known methods', () {
      expect(
        settingsMeta['payments.enabled_methods']!.options,
        containsAll(['clickpesa', 'cash', 'manual']),
      );
    });

    test('finance.payout_schedule offers four cadences', () {
      expect(
        settingsMeta['finance.payout_schedule']!.options,
        containsAll(['daily', 'weekly', 'biweekly', 'monthly']),
      );
    });
  });

  group('categoryLabel', () {
    test('returns human-readable labels', () {
      expect(categoryLabel('location'), 'Location');
      expect(categoryLabel('batching'), 'Batching');
      expect(categoryLabel('app'), 'App');
    });

    test('capitalizes unknown categories', () {
      expect(categoryLabel('something'), 'Something');
    });
  });

  group('optionLabel', () {
    test('converts snake_case to title case', () {
      expect(optionLabel('flat_per_package'), 'Flat Per Package');
      expect(optionLabel('clickpesa'), 'Clickpesa');
    });
  });
}