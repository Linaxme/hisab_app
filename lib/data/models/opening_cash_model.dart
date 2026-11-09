import 'package:cloud_firestore/cloud_firestore.dart';

class OpeningCashModel {
  final String id; // date as id: YYYY-MM-DD
  final double amount;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Day-close (drawer count) recorded at the end of this date
  final double? closingExpected;
  final double? closingCounted;
  final DateTime? closedAt;

  /// Excess cash added as a sale to make the count match (0 when none).
  final double closingAdjustment;

  OpeningCashModel({
    required this.id,
    required this.amount,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.closingExpected,
    this.closingCounted,
    this.closedAt,
    this.closingAdjustment = 0,
  });

  bool get isClosed => closingCounted != null;

  /// Counted minus expected: negative is a shortage, positive an excess.
  double get closingDifference => (closingCounted ?? 0) - (closingExpected ?? 0);

  factory OpeningCashModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OpeningCashModel(
      id: doc.id,
      amount: (data['amount'] ?? 0).toDouble(),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      closingExpected: (data['closingExpected'] as num?)?.toDouble(),
      closingCounted: (data['closingCounted'] as num?)?.toDouble(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      closingAdjustment: (data['closingAdjustment'] as num?)?.toDouble() ?? 0,
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
      closingExpected: closingExpected,
      closingCounted: closingCounted,
      closedAt: closedAt,
      closingAdjustment: closingAdjustment,
    );
  }
}
