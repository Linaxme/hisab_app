import 'package:cloud_firestore/cloud_firestore.dart';

class CreditSaleModel {
  final String id;
  final String? customerName;
  final String? customerPhone;
  final double amount;
  final double collectedAmount;
  final String date; // YYYY-MM-DD
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CreditSaleModel({
    required this.id,
    this.customerName,
    this.customerPhone,
    required this.amount,
    this.collectedAmount = 0,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  double get remainingAmount => amount - collectedAmount;
  bool get isFullyPaid => remainingAmount <= 0;

  factory CreditSaleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CreditSaleModel(
      id: doc.id,
      customerName: data['customerName'],
      customerPhone: data['customerPhone'],
      amount: (data['amount'] ?? 0).toDouble(),
      collectedAmount: (data['collectedAmount'] ?? 0).toDouble(),
      date: data['date'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'amount': amount,
      'collectedAmount': collectedAmount,
      'date': date,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': null,
    };
  }

  Map<String, dynamic> toUpdateFirestore() {
    return {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'amount': amount,
      'date': date,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CreditSaleModel copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    double? amount,
    double? collectedAmount,
    String? date,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreditSaleModel(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      amount: amount ?? this.amount,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CreditCollectionModel {
  final String id;
  final String creditSaleId;
  final double amount;
  final String date; // YYYY-MM-DD
  final String createdBy;
  final DateTime createdAt;

  CreditCollectionModel({
    required this.id,
    required this.creditSaleId,
    required this.amount,
    required this.date,
    required this.createdBy,
    required this.createdAt,
  });

  factory CreditCollectionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CreditCollectionModel(
      id: doc.id,
      creditSaleId: data['creditSaleId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: data['date'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creditSaleId': creditSaleId,
      'amount': amount,
      'date': date,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
