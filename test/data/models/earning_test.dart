import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/earning.dart';

Map<String, dynamic> _baseJson() => {
      'id': 1,
      'user_id': 42,
      'delivery_id': 100,
      'type': 'rider_baseline',
      'amount': 1600.00,
      'currency': 'TZS',
      'status': 'pending',
      'earned_at': '2026-10-24T07:00:00+00:00',
      'approved_by': null,
      'approved_at': null,
      'payout_id': null,
      'paid_at': null,
      'notes': null,
      'metadata': null,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

void main() {
  group('EarningType enum', () {
    test('fromString maps all six types', () {
      const values = [
        'rider_baseline', 'rider_bonus',
        'dispatcher_flat', 'dispatcher_shift', 'dispatcher_percent',
        'adjustment',
      ];
      for (final v in values) {
        expect(EarningType.fromString(v).name, v);
      }
    });

    test('fromString falls back to adjustment', () {
      expect(EarningType.fromString('tip'), EarningType.adjustment);
    });

    test('isRider, isDispatcher, isAdjustment', () {
      expect(EarningType.rider_baseline.isRider, isTrue);
      expect(EarningType.rider_bonus.isRider, isTrue);
      expect(EarningType.dispatcher_flat.isRider, isFalse);

      expect(EarningType.dispatcher_flat.isDispatcher, isTrue);
      expect(EarningType.dispatcher_shift.isDispatcher, isTrue);
      expect(EarningType.dispatcher_percent.isDispatcher, isTrue);
      expect(EarningType.rider_baseline.isDispatcher, isFalse);

      expect(EarningType.adjustment.isAdjustment, isTrue);
    });

    test('displayLabel returns human-readable text', () {
      expect(EarningType.rider_baseline.displayLabel, 'Rider baseline');
      expect(EarningType.rider_bonus.displayLabel, 'Rider bonus');
      expect(EarningType.dispatcher_shift.displayLabel, 'Dispatcher (shift)');
    });
  });

  group('EarningStatus enum', () {
    test('fromString maps all four statuses', () {
      expect(EarningStatus.fromString('pending'), EarningStatus.pending);
      expect(EarningStatus.fromString('approved'), EarningStatus.approved);
      expect(EarningStatus.fromString('paid'), EarningStatus.paid);
      expect(EarningStatus.fromString('cancelled'), EarningStatus.cancelled);
    });

    test('fromString falls back to unknown', () {
      expect(EarningStatus.fromString('disputed'), EarningStatus.unknown);
    });
  });

  group('Earning.fromJson', () {
    test('parses rider baseline earning', () {
      final e = Earning.fromJson(_baseJson());
      expect(e.id, 1);
      expect(e.userId, 42);
      expect(e.deliveryId, 100);
      expect(e.type, EarningType.rider_baseline);
      expect(e.amount, 1600.0);
      expect(e.currency, 'TZS');
      expect(e.status, EarningStatus.pending);
      expect(e.isRiderEarning, isTrue);
      expect(e.isDispatcherEarning, isFalse);
      expect(e.isPositive, isTrue);
      expect(e.isNegative, isFalse);
      expect(e.isPending, isTrue);
    });

    test('parses rider bonus', () {
      final e = Earning.fromJson(_baseJson()
        ..['type'] = 'rider_bonus'
        ..['amount'] = 200.00);
      expect(e.type, EarningType.rider_bonus);
      expect(e.amount, 200.0);
      expect(e.isRiderEarning, isTrue);
    });

    test('parses dispatcher shift earning with null delivery_id', () {
      final e = Earning.fromJson(_baseJson()
        ..['type'] = 'dispatcher_shift'
        ..['delivery_id'] = null
        ..['amount'] = 5000.00);
      expect(e.type, EarningType.dispatcher_shift);
      expect(e.deliveryId, isNull);
      expect(e.isDispatcherEarning, isTrue);
    });

    test('parses negative adjustment', () {
      final e = Earning.fromJson(_baseJson()
        ..['type'] = 'adjustment'
        ..['amount'] = -250.00
        ..['notes'] = 'Clawback for cancelled delivery');
      expect(e.type, EarningType.adjustment);
      expect(e.amount, -250.0);
      expect(e.isNegative, isTrue);
      expect(e.isPositive, isFalse);
      expect(e.isAdjustment, isTrue);
      expect(e.notes, 'Clawback for cancelled delivery');
    });

    test('parses paid earning with full lifecycle timestamps', () {
      final e = Earning.fromJson(_baseJson()
        ..['status'] = 'paid'
        ..['approved_by'] = 7
        ..['approved_at'] = '2026-10-24T08:00:00+00:00'
        ..['payout_id'] = 55
        ..['paid_at'] = '2026-10-25T10:00:00+00:00');
      expect(e.isPaid, isTrue);
      expect(e.approvedBy, 7);
      expect(e.approvedAt, isNotNull);
      expect(e.payoutId, 55);
      expect(e.paidAt, isNotNull);
    });
  });

  group('Earning display helpers', () {
    test('amountLabel formats positive amounts', () {
      final e = Earning.fromJson(_baseJson());
      expect(e.amountLabel, 'TZS 1600');
    });

    test('amountLabel prefixes negative amounts with a dash', () {
      final e = Earning.fromJson(_baseJson()
        ..['type'] = 'adjustment'
        ..['amount'] = -250.00);
      expect(e.amountLabel, '-TZS 250');
    });

    test('typeLabel and statusLabel reflect enums', () {
      final e = Earning.fromJson(_baseJson());
      expect(e.typeLabel, 'Rider baseline');
      expect(e.statusLabel, 'Pending');
    });
  });

  group('Earning round-trip', () {
    test('fromJson → toJson → fromJson preserves all fields', () {
      final original = Earning.fromJson(_baseJson()
        ..['approved_by'] = 7
        ..['approved_at'] = '2026-10-24T08:00:00+00:00');
      final roundtripped = Earning.fromJson(original.toJson());
      expect(roundtripped.id, original.id);
      expect(roundtripped.type, original.type);
      expect(roundtripped.amount, original.amount);
      expect(roundtripped.status, original.status);
      expect(roundtripped.approvedBy, original.approvedBy);
    });

    test('negative amount preserved through round-trip', () {
      final original = Earning.fromJson(_baseJson()
        ..['type'] = 'adjustment'
        ..['amount'] = -250.00);
      final roundtripped = Earning.fromJson(original.toJson());
      expect(roundtripped.amount, -250.0);
      expect(roundtripped.isNegative, isTrue);
    });
  });
}