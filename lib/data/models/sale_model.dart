import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentType { cash, noncash }

class SaleModel {
  final String id;
  final String productName;
  final double sellPrice;
  final double profit;
  final PaymentType paymentType;
  final String date; // YYYY-MM-DD
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Excess cash found at day close, booked as a forgotten sale.
  final bool isAdjustment;

  /// Stocked product sold and how much of it; stock moves by [quantity]
  final String? productId;
  final double? quantity;

  SaleModel({
    required this.id,
    required this.productName,
    required this.sellPrice,
    required this.profit,
    required this.paymentType,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isAdjustment = false,
    this.productId,
    this.quantity,
  });

  /// Stock this sale takes out, keyed by product
  Map<String, double> get stockUse =>
      productId != null && (quantity ?? 0) > 0 ? {productId!: quantity!} : const {};

  factory SaleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SaleModel(
      id: doc.id,
      productName: data['productName'] ?? '',
      sellPrice: (data['sellPrice'] ?? 0).toDouble(),
      profit: (data['profit'] ?? 0).toDouble(),
      paymentType: data['paymentType'] == 'noncash' 
          ? PaymentType.noncash 
          : PaymentType.cash,
      date: data['date'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isAdjustment: data['isAdjustment'] == true,
      productId: data['productId'],
      quantity: (data['quantity'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productName': productName,
      'sellPrice': sellPrice,
      'profit': profit,
      'paymentType': paymentType == PaymentType.cash ? 'cash' : 'noncash',
      'date': date,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      if (isAdjustment) 'isAdjustment': true,
      if (stockUse.isNotEmpty) 'productId': productId,
      if (stockUse.isNotEmpty) 'quantity': quantity,
    };
  }

  Map<String, dynamic> toUpdateFirestore() {
    return {
      'productName': productName,
      'sellPrice': sellPrice,
      'profit': profit,
      'paymentType': paymentType == PaymentType.cash ? 'cash' : 'noncash',
      'date': date,
      'productId': stockUse.isEmpty ? null : productId,
      'quantity': stockUse.isEmpty ? null : quantity,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  SaleModel copyWith({
    String? id,
    String? productName,
    double? sellPrice,
    double? profit,
    PaymentType? paymentType,
    String? date,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SaleModel(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      sellPrice: sellPrice ?? this.sellPrice,
      profit: profit ?? this.profit,
      paymentType: paymentType ?? this.paymentType,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAdjustment: isAdjustment,
      productId: productId,
      quantity: quantity,
    );
  }

  bool get isCash => paymentType == PaymentType.cash;
}
