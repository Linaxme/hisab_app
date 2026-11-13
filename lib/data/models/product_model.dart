import 'package:cloud_firestore/cloud_firestore.dart';

/// Product model for product names, plus stock details when the Stock add-on tracks it
class ProductModel {
  final String id;
  final String name;
  final bool active;
  final DateTime createdAt;

  /// Stock is counted for this product (Stock add-on)
  final bool trackStock;
  final double stockQty;
  final String unit;
  final double? buyPrice;
  final double? sellPrice;

  /// Warn when stock falls to this quantity or below
  final double? lowStockAt;

  ProductModel({
    required this.id,
    required this.name,
    this.active = true,
    required this.createdAt,
    this.trackStock = false,
    this.stockQty = 0,
    this.unit = 'পিস',
    this.buyPrice,
    this.sellPrice,
    this.lowStockAt,
  });

  bool get isLowStock => trackStock && stockQty <= (lowStockAt ?? 0);

  /// Stock on hand valued at the buy price
  double get stockValue => trackStock && stockQty > 0 ? stockQty * (buyPrice ?? 0) : 0;

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      active: data['active'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      trackStock: data['trackStock'] == true,
      stockQty: (data['stockQty'] as num?)?.toDouble() ?? 0,
      unit: (data['unit'] as String?)?.trim().isNotEmpty == true ? data['unit'] : 'পিস',
      buyPrice: (data['buyPrice'] as num?)?.toDouble(),
      sellPrice: (data['sellPrice'] as num?)?.toDouble(),
      lowStockAt: (data['lowStockAt'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      if (trackStock) ...stockFields(),
      if (trackStock) 'stockQty': stockQty,
    };
  }

  /// Stock settings (everything except the quantity, which only moves by increments)
  Map<String, dynamic> stockFields() {
    return {
      'trackStock': trackStock,
      'unit': unit,
      'buyPrice': buyPrice,
      'sellPrice': sellPrice,
      'lowStockAt': lowStockAt,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    bool? active,
    DateTime? createdAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      trackStock: trackStock,
      stockQty: stockQty,
      unit: unit,
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      lowStockAt: lowStockAt,
    );
  }

  /// Whether another product already uses [name]. Sales find stock by name, so names must be unique.
  static bool nameTaken(Iterable<ProductModel> products, String name, {String? exceptId}) {
    final key = name.trim().toLowerCase();
    return products.any((p) => p.id != exceptId && p.name.trim().toLowerCase() == key);
  }
}

/// A stock movement: goods received ('in') or a count correction ('adjust')
class StockEntryModel {
  final String id;
  final String productId;
  final String productName;
  final String type;
  final double quantity;
  final double? buyPrice;
  final String? note;
  final String date; // YYYY-MM-DD
  final String createdBy;
  final DateTime createdAt;

  StockEntryModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    this.buyPrice,
    this.note,
    required this.date,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isAdjustment => type == 'adjust';

  factory StockEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockEntryModel(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      type: data['type'] ?? 'in',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      buyPrice: (data['buyPrice'] as num?)?.toDouble(),
      note: data['note'],
      date: data['date'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      'type': type,
      'quantity': quantity,
      if (buyPrice != null) 'buyPrice': buyPrice,
      if (note != null && note!.isNotEmpty) 'note': note,
      'date': date,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
