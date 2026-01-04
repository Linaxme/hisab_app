import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnModel {
  final String id;
  final double amount;
  final String? note;
  final String date; // YYYY-MM-DD
  final String createdBy;
  final DateTime createdAt;

  ReturnModel({
    required this.id,
    required this.amount,
    this.note,
    required this.date,
    required this.createdBy,
    required this.createdAt,
  });

  factory ReturnModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReturnModel(
      id: doc.id,
      amount: (data['amount'] ?? 0).toDouble(),
      note: data['note'],
      date: data['date'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'note': note,
      'date': date,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateFirestore() {
    return {
      'amount': amount,
      'note': note,
      'date': date,
    };
  }

  ReturnModel copyWith({
    String? id,
    double? amount,
    String? note,
    String? date,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return ReturnModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
