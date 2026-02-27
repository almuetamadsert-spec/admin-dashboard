/// عنصر طلب (منتج داخل الطلب)
class MyOrderItem {
  final int id;
  final int? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? imagePath;

  MyOrderItem({
    required this.id,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.imagePath,
  });

  factory MyOrderItem.fromJson(Map<String, dynamic> json) {
    return MyOrderItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt(),
      productName: (json['product_name'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      imagePath: (json['image_path'] as String?)?.trim(),
    );
  }
}

/// طلب العميل (لشاشة طلباتي)
class MyOrder {
  final int id;
  final String orderNumber;
  final String status; // pending | confirmed | shipped | delivered | cancelled
  final double totalAmount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<MyOrderItem> items;

  MyOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    this.updatedAt,
    required this.items,
  });

  /// أول صورة منتج في الطلب (للعرض في القائمة)
  String? get firstImagePath {
    for (final item in items) {
      if (item.imagePath != null && item.imagePath!.isNotEmpty) return item.imagePath;
    }
    return null;
  }

  /// هل تم قبول الطلب من التاجر (قيد التنفيذ أو ما بعد)
  bool get isAccepted => status != 'pending' && status != 'cancelled';

  /// وقت قبول الطلب (updated_at عند تغيير الحالة من pending)
  DateTime? get acceptedAt => updatedAt;

  factory MyOrder.fromJson(Map<String, dynamic> json) {
    final created = json['created_at']?.toString();
    final updated = json['updated_at']?.toString();
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return MyOrder(
      id: (json['id'] as num).toInt(),
      orderNumber: (json['order_number'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      createdAt: created != null ? DateTime.tryParse(created) ?? DateTime.now() : DateTime.now(),
      updatedAt: updated != null ? DateTime.tryParse(updated) : null,
      items: itemsList.map((e) => MyOrderItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
