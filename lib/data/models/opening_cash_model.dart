import 'package:cloud_firestore/cloud_firestore.dart';

/// A drawer count (`cashChecks`). A difference can be booked so live cash
/// matches the count: an excess as a cash sale, a shortage as a cash expense
/// ([adjustmentId] is that sale or expense).
class CashCheckModel {
  final String id;
  final String date; // YYYY-MM-DD
  final double counted;

  /// Live cash at the count, including [adjustment].
  final double expected;

  /// Positive: booked as a sale; negative: booked as an expense.
  final double adjustment;
  final String? adjustmentId;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  const CashCheckModel({
    required this.id,
    required this.date,
    required this.counted,
    required this.expected,
    this.adjustment = 0,
    this.adjustmentId,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  /// Counted minus expected: negative is a shortage, positive an excess.
  double get difference => counted - expected;

  factory CashCheckModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CashCheckModel(
      id: doc.id,
      date: data['date'] ?? '',
      counted: (data['counted'] as num?)?.toDouble() ?? 0,
      expected: (data['expected'] as num?)?.toDouble() ?? 0,
      adjustment: (data['adjustment'] as num?)?.toDouble() ?? 0,
      adjustmentId: (data['adjustmentId'] ?? data['adjustmentSaleId']) as String?,
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'date': date,
        'counted': counted,
        'expected': expected,
        if (adjustment != 0) 'adjustment': adjustment,
        if (adjustmentId != null) 'adjustmentId': adjustmentId,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class OpeningCashModel {
  final String id; // date as id: YYYY-MM-DD
  final double amount;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Drawer count of the former day close, kept for days closed with it
  final double? closingExpected;
  final double? closingCounted;
  final DateTime? closedAt;

  /// Excess cash added as a sale to make the count match (0 when none).
  final double closingAdjustment;

  /// The day's own net cash flow (without its opening) when it was closed.
  final double? closingNet;

  /// Previous day whose end cash this opening follows ('' when there was
  /// none); null when the opening was set by hand.
  final String? carriedFrom;

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
    this.closingNet,
    this.carriedFrom,
  });

  bool get isClosed => closingCounted != null;

  bool get followsPreviousDay => carriedFrom != null;

  /// Counted minus expected: negative is a shortage, positive an excess.
  double get closingDifference => (closingCounted ?? 0) - (closingExpected ?? 0);

  /// Cash in the drawer at the end of this day, given its own net flow. A day
  /// closed with the former day close keeps its counted cash plus what moved
  /// after that count.
  double endCash(double net) =>
      isClosed && closingNet != null ? closingCounted! + net - closingNet! : amount + net;

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
      closingNet: (data['closingNet'] as num?)?.toDouble(),
      carriedFrom: data['carriedFrom'] as String?,
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
      closingNet: closingNet,
      carriedFrom: carriedFrom,
    );
  }
}
