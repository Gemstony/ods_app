import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/payment.dart';

Map<String, dynamic> _pendingJson() => {
      'id': 1,
      'delivery_id': 100,
      'stage': 'full',
      'amount': 2000.00,
      'currency': 'TZS',
      'method': 'clickpesa',
      'status': 'pending',
      'reference': 'PAY-20261024-ABC123',
      'provider_reference': null,
      'initiated_by': 42,
      'initiated_at': '2026-10-24T07:00:00+00:00',
      'paid_at': null,
      'failed_at': null,
      'expires_at': null,
      'failure_reason': null,
      'metadata': null,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

Map<String, dynamic> _completedJson() => {
      ..._pendingJson(),
      'status': 'completed',
      'provider_reference': 'CP-REF-999',
      'paid_at': '2026-10-24T07:02:00+00:00',
    };

void main() {
  group('PaymentStage enum', () {
    test('fromString maps all three stages', () {
      expect(PaymentStage.fromString('full'), PaymentStage.full);
      expect(PaymentStage.fromString('ods_fee'), PaymentStage.ods_fee);
      expect(
          PaymentStage.fromString('transport_fare'), PaymentStage.transport_fare);
    });

    test('fromString falls back to full on unknown', () {
      expect(PaymentStage.fromString('deposit'), PaymentStage.full);
    });

    test('isRegionalStage is true for ods_fee and transport_fare', () {
      expect(PaymentStage.full.isRegionalStage, isFalse);
      expect(PaymentStage.ods_fee.isRegionalStage, isTrue);
      expect(PaymentStage.transport_fare.isRegionalStage, isTrue);
    });

    test('displayLabel returns human-readable text', () {
      expect(PaymentStage.full.displayLabel, 'Full payment');
      expect(PaymentStage.ods_fee.displayLabel, 'ODS delivery fee');
      expect(PaymentStage.transport_fare.displayLabel, 'Transport fare');
    });
  });

  group('PaymentStatus enum', () {
    test('fromString maps all seven statuses', () {
      const values = [
        'pending', 'processing', 'completed', 'failed',
        'cancelled', 'refunded', 'expired',
      ];
      for (final v in values) {
        expect(PaymentStatus.fromString(v).name, v);
      }
    });

    test('fromString falls back to unknown', () {
      expect(PaymentStatus.fromString('voided'), PaymentStatus.unknown);
    });

    test('isTerminal covers completed, failed, cancelled, refunded, expired',
        () {
      expect(PaymentStatus.completed.isTerminal, isTrue);
      expect(PaymentStatus.failed.isTerminal, isTrue);
      expect(PaymentStatus.cancelled.isTerminal, isTrue);
      expect(PaymentStatus.refunded.isTerminal, isTrue);
      expect(PaymentStatus.expired.isTerminal, isTrue);
      expect(PaymentStatus.pending.isTerminal, isFalse);
      expect(PaymentStatus.processing.isTerminal, isFalse);
    });

    test('isInFlight true only for pending and processing', () {
      expect(PaymentStatus.pending.isInFlight, isTrue);
      expect(PaymentStatus.processing.isInFlight, isTrue);
      expect(PaymentStatus.completed.isInFlight, isFalse);
    });
  });

  group('Payment.fromJson', () {
    test('parses a pending payment', () {
      final p = Payment.fromJson(_pendingJson());

      expect(p.id, 1);
      expect(p.deliveryId, 100);
      expect(p.stage, PaymentStage.full);
      expect(p.amount, 2000.0);
      expect(p.currency, 'TZS');
      expect(p.method, PaymentMethod.clickpesa);
      expect(p.status, PaymentStatus.pending);
      expect(p.reference, 'PAY-20261024-ABC123');
      expect(p.providerReference, isNull);
      expect(p.paidAt, isNull);
      expect(p.isPending, isTrue);
      expect(p.isCompleted, isFalse);
    });

    test('parses a completed payment with provider reference', () {
      final p = Payment.fromJson(_completedJson());
      expect(p.status, PaymentStatus.completed);
      expect(p.providerReference, 'CP-REF-999');
      expect(p.paidAt, isNotNull);
      expect(p.isCompleted, isTrue);
      expect(p.isPending, isFalse);
    });

    test('parses regional stage payments', () {
      final ods = Payment.fromJson(_pendingJson()..['stage'] = 'ods_fee');
      expect(ods.stage, PaymentStage.ods_fee);
      expect(ods.isRegionalStage, isTrue);

      final transport =
          Payment.fromJson(_pendingJson()..['stage'] = 'transport_fare');
      expect(transport.stage, PaymentStage.transport_fare);
      expect(transport.isRegionalStage, isTrue);
    });

    test('parses failed payment with reason', () {
      final p = Payment.fromJson(_pendingJson()
        ..['status'] = 'failed'
        ..['failed_at'] = '2026-10-24T07:05:00+00:00'
        ..['failure_reason'] = 'Insufficient funds');
      expect(p.status, PaymentStatus.failed);
      expect(p.isFailed, isTrue);
      expect(p.failureReason, 'Insufficient funds');
      expect(p.failedAt, isNotNull);
    });

    test('parses metadata map', () {
      final p = Payment.fromJson(_pendingJson()
        ..['metadata'] = {'ussd_code': '*150*00#'});
      expect(p.metadata, {'ussd_code': '*150*00#'});
    });
  });

  group('Payment display helpers', () {
    test('amountLabel formats amount with currency', () {
      final p = Payment.fromJson(_pendingJson());
      expect(p.amountLabel, 'TZS 2000');
    });

    test('stageLabel reflects stage', () {
      final p = Payment.fromJson(_pendingJson());
      expect(p.stageLabel, 'Full payment');
    });

    test('statusLabel reflects status', () {
      final p = Payment.fromJson(_pendingJson());
      expect(p.statusLabel, 'Pending');
    });

    test('methodLabel reflects method', () {
      final p = Payment.fromJson(_pendingJson());
      expect(p.methodLabel, 'ClickPesa');
    });
  });

  group('Payment round-trip', () {
    test('pending: fromJson → toJson → fromJson', () {
      final original = Payment.fromJson(_pendingJson());
      final roundtripped = Payment.fromJson(original.toJson());
      expect(roundtripped.id, original.id);
      expect(roundtripped.stage, original.stage);
      expect(roundtripped.amount, original.amount);
      expect(roundtripped.status, original.status);
      expect(roundtripped.reference, original.reference);
    });

    test('completed: preserves provider reference and paid_at', () {
      final original = Payment.fromJson(_completedJson());
      final roundtripped = Payment.fromJson(original.toJson());
      expect(roundtripped.providerReference, original.providerReference);
      expect(roundtripped.paidAt, original.paidAt);
    });
  });

  group('Payment defensive parsing', () {
    test('accepts integer amount', () {
      final p = Payment.fromJson(_pendingJson()..['amount'] = 2000);
      expect(p.amount, 2000.0);
    });

    test('accepts string id', () {
      final p = Payment.fromJson(_pendingJson()
        ..['id'] = '1'
        ..['delivery_id'] = '100');
      expect(p.id, 1);
      expect(p.deliveryId, 100);
    });
  });
}