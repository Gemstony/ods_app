import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/delivery_item.dart';

Map<String, dynamic> _manualProductJson() => {
      'id': 1,
      'delivery_id': 100,
      'exgo_order_id': null,
      'product_name': 'Salmon Oil',
      'product_code': 'SLM-001',
      'quantity': 2,
      'notes': null,
      'sort_order': 0,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

Map<String, dynamic> _exgoJson() => {
      'id': 2,
      'delivery_id': 100,
      'exgo_order_id': 'EXGO-12345',
      'product_name': null,
      'product_code': null,
      'quantity': null,
      'notes': null,
      'sort_order': 1,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

Map<String, dynamic> _hybridJson() => {
      'id': 3,
      'delivery_id': 100,
      'exgo_order_id': 'EXGO-99999',
      'product_name': 'Full Motion',
      'product_code': 'FLM-003',
      'quantity': 1,
      'notes': 'Confirmed via NeoLife API',
      'sort_order': 2,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

void main() {
  group('DeliveryItem.fromJson — manual product', () {
    test('parses all product fields', () {
      final item = DeliveryItem.fromJson(_manualProductJson());
      expect(item.id, 1);
      expect(item.deliveryId, 100);
      expect(item.productName, 'Salmon Oil');
      expect(item.productCode, 'SLM-001');
      expect(item.quantity, 2);
      expect(item.sortOrder, 0);
    });

    test('isManualProduct true, isExgoReference false', () {
      final item = DeliveryItem.fromJson(_manualProductJson());
      expect(item.isManualProduct, isTrue);
      expect(item.isExgoReference, isFalse);
    });

    test('displayLabel formats as "qty × name"', () {
      final item = DeliveryItem.fromJson(_manualProductJson());
      expect(item.displayLabel, '2 × Salmon Oil');
    });
  });

  group('DeliveryItem.fromJson — EXGO reference', () {
    test('parses exgo_order_id', () {
      final item = DeliveryItem.fromJson(_exgoJson());
      expect(item.exgoOrderId, 'EXGO-12345');
      expect(item.productName, isNull);
      expect(item.quantity, isNull);
    });

    test('isExgoReference true, isManualProduct false', () {
      final item = DeliveryItem.fromJson(_exgoJson());
      expect(item.isExgoReference, isTrue);
      expect(item.isManualProduct, isFalse);
    });

    test('displayLabel shows EXGO order id', () {
      final item = DeliveryItem.fromJson(_exgoJson());
      expect(item.displayLabel, 'EXGO EXGO-12345');
    });
  });

  group('DeliveryItem.fromJson — hybrid', () {
    test('can have both EXGO id and product details', () {
      final item = DeliveryItem.fromJson(_hybridJson());
      expect(item.exgoOrderId, 'EXGO-99999');
      expect(item.productName, 'Full Motion');
      expect(item.quantity, 1);
      expect(item.isExgoReference, isTrue);
      expect(item.isManualProduct, isTrue);
    });

    test('displayLabel prefers product info when both are present', () {
      final item = DeliveryItem.fromJson(_hybridJson());
      expect(item.displayLabel, '1 × Full Motion');
    });
  });

  group('DeliveryItem edge cases', () {
    test('empty exgo_order_id is not considered an EXGO reference', () {
      final json = _manualProductJson()..['exgo_order_id'] = '';
      final item = DeliveryItem.fromJson(json);
      expect(item.isExgoReference, isFalse);
    });

    test('empty product_name is not considered a manual product', () {
      final json = _manualProductJson()..['product_name'] = '';
      final item = DeliveryItem.fromJson(json);
      expect(item.isManualProduct, isFalse);
    });

    test('displayLabel falls back to id when nothing else is available', () {
      final json = _manualProductJson()
        ..['product_name'] = null
        ..['exgo_order_id'] = null;
      final item = DeliveryItem.fromJson(json);
      expect(item.displayLabel, 'Item #1');
    });

    test('null quantity defaults to 1 in displayLabel', () {
      final json = _manualProductJson()..['quantity'] = null;
      final item = DeliveryItem.fromJson(json);
      expect(item.displayLabel, '1 × Salmon Oil');
    });
  });

  group('DeliveryItem round-trip', () {
    test('manual product: fromJson → toJson → fromJson', () {
      final original = DeliveryItem.fromJson(_manualProductJson());
      final roundtripped = DeliveryItem.fromJson(original.toJson());

      expect(roundtripped.id, original.id);
      expect(roundtripped.productName, original.productName);
      expect(roundtripped.quantity, original.quantity);
    });

    test('EXGO: preserves exgo_order_id', () {
      final original = DeliveryItem.fromJson(_exgoJson());
      final roundtripped = DeliveryItem.fromJson(original.toJson());
      expect(roundtripped.exgoOrderId, original.exgoOrderId);
    });

    test('hybrid: preserves both sides', () {
      final original = DeliveryItem.fromJson(_hybridJson());
      final roundtripped = DeliveryItem.fromJson(original.toJson());
      expect(roundtripped.exgoOrderId, 'EXGO-99999');
      expect(roundtripped.productName, 'Full Motion');
    });
  });

  group('DeliveryItem sortOrder', () {
    test('defaults to 0 when missing', () {
      final json = Map<String, dynamic>.from(_manualProductJson())
        ..remove('sort_order');
      final item = DeliveryItem.fromJson(json);
      expect(item.sortOrder, 0);
    });

    test('preserves explicit sortOrder', () {
      final json = _manualProductJson()..['sort_order'] = 5;
      final item = DeliveryItem.fromJson(json);
      expect(item.sortOrder, 5);
    });
  });
}