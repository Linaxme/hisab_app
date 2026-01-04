import 'package:cloud_firestore/cloud_firestore.dart';

class OpeningCashModel {
  final String id; // date as id: YYYY-MM-DD
  final double amount;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OpeningCashModel({
    required this.id,
    required this.amount,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory OpeningCashModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OpeningCashModel(
      id: doc.id,
      amount: (data['amount'] ?? 0).toDouble(),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': null,
    };
  }

  Map<String, dynamic> toUpdateFirestore() {
    return {
      'amount': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  OpeningCashModel copyWith({
    String? id,
    double? amount,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OpeningCashModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
