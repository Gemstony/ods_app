import '../../core/utils/json_helpers.dart';

/// A single line item within a delivery.
///
/// The ODS document supports two input methods:
///
///   **M-Commerce (EXGO)**: `exgoOrderId` is set, product fields may be
///   null (unless the app can retrieve order details from NeoLife).
///
///   **WhatsApp orders**: `productName`, `productCode`, `quantity` are set,
///   `exgoOrderId` is null.
///
/// A single row can carry both if the app can verify EXGO details AND the
/// distributor also supplied them. The helpers below check each side
/// independently.
class DeliveryItem {
  final int id;
  final int deliveryId;

  // ─── EXGO reference (M-Commerce) ─────────────────────────
  final String? exgoOrderId;

  // ─── Product details (WhatsApp / manual) ─────────────────
  final String? productName;
  final String? productCode;
  final int? quantity;

  // ─── Common ──────────────────────────────────────────────
  final String? notes;
  final int sortOrder;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DeliveryItem({
    required this.id,
    required this.deliveryId,
    required this.sortOrder,
    this.exgoOrderId,
    this.productName,
    this.productCode,
    this.quantity,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryItem.fromJson(Map<String, dynamic> json) {
    return DeliveryItem(
      id: asInt(json['id']),
      deliveryId: asInt(json['delivery_id']),
      exgoOrderId: json['exgo_order_id'] as String?,
      productName: json['product_name'] as String?,
      productCode: json['product_code'] as String?,
      quantity: json['quantity'] == null ? null : asInt(json['quantity']),
      notes: json['notes'] as String?,
      sortOrder: asInt(json['sort_order'] ?? 0),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'delivery_id': deliveryId,
        'exgo_order_id': exgoOrderId,
        'product_name': productName,
        'product_code': productCode,
        'quantity': quantity,
        'notes': notes,
        'sort_order': sortOrder,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  // ─── Type helpers ────────────────────────────────────────
  bool get isExgoReference => exgoOrderId != null && exgoOrderId!.isNotEmpty;

  bool get isManualProduct =>
      productName != null && productName!.isNotEmpty;

  /// Best-effort one-line summary for UI: prefers product info, falls back
  /// to the EXGO order reference.
  String get displayLabel {
    if (isManualProduct) {
      final qty = quantity ?? 1;
      return '$qty × $productName';
    }
    if (isExgoReference) {
      return 'EXGO $exgoOrderId';
    }
    return 'Item #$id';
  }
}