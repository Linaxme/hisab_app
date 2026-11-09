import 'package:cloud_firestore/cloud_firestore.dart';
import 'sale_model.dart';

class ReturnModel {
  final String id;
  final double amount;
  final String? note;
  final PaymentType paymentType;
  final String date; // YYYY-MM-DD
  final String createdBy;
  final DateTime createdAt;

  ReturnModel({
    required this.id,
    required this.amount,
    this.note,
    this.paymentType = PaymentType.cash,
    required this.date,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isCash => paymentType == PaymentType.cash;

  factory ReturnModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReturnModel(
      id: doc.id,
      amount: (data['amount'] ?? 0).toDouble(),
      note: data['note'],
      paymentType: data['paymentType'] == 'noncash'
          ? PaymentType.noncash
          : PaymentType.cash,
      date: data['date'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'note': note,
      'paymentType': isCash ? 'cash' : 'noncash',
      'date': date,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateFirestore() {
    return {
      'amount': amount,
      'note': note,
      'paymentType': isCash ? 'cash' : 'noncash',
      'date': date,
    };
  }

  ReturnModel copyWith({
    String? id,
    double? amount,
    String? note,
    PaymentType? paymentType,
    String? date,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return ReturnModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      paymentType: paymentType ?? this.paymentType,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
