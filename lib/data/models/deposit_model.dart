import 'package:cloud_firestore/cloud_firestore.dart';

class DepositModel {
  final String id;
  final double amount;
  final String? note;
  final String date; // YYYY-MM-DD
  final String createdBy;
  final DateTime createdAt;
  final bool isAutoCreated; // true if created from non-cash sale
  final String? saleId; // the non-cash sale this deposit was auto-created for

  DepositModel({
    required this.id,
    required this.amount,
    this.note,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    this.isAutoCreated = false,
    this.saleId,
  });

  factory DepositModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DepositModel(
      id: doc.id,
      amount: (data['amount'] ?? 0).toDouble(),
      note: data['note'],
      date: data['date'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAutoCreated: data['isAutoCreated'] ?? false,
      saleId: data['saleId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'note': note,
      'date': date,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'isAutoCreated': isAutoCreated,
      if (saleId != null) 'saleId': saleId,
    };
  }

  Map<String, dynamic> toUpdateFirestore() {
    return {
      'amount': amount,
      'note': note,
      'date': date,
    };
  }

  DepositModel copyWith({
    String? id,
    double? amount,
    String? note,
    String? date,
    String? createdBy,
    DateTime? createdAt,
    bool? isAutoCreated,
    String? saleId,
  }) {
    return DepositModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isAutoCreated: isAutoCreated ?? this.isAutoCreated,
      saleId: saleId ?? this.saleId,
    );
  }
}
