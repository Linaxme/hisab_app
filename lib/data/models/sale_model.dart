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
  });

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
    };
  }

  Map<String, dynamic> toUpdateFirestore() {
    return {
      'productName': productName,
      'sellPrice': sellPrice,
      'profit': profit,
      'paymentType': paymentType == PaymentType.cash ? 'cash' : 'noncash',
      'date': date,
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
    );
  }

  bool get isCash => paymentType == PaymentType.cash;
}
