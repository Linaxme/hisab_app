import 'package:cloud_firestore/cloud_firestore.dart';

/// Paid add-ons of one shop (`shopPremium/{shopId}`); only the app admin writes it.
class ShopPremiumModel {
  final String shopId;
  final DateTime? stockUntil;

  const ShopPremiumModel({required this.shopId, this.stockUntil});

  bool get isStockActive => stockUntil != null && stockUntil!.isAfter(DateTime.now());

  factory ShopPremiumModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return ShopPremiumModel(
      shopId: doc.id,
      stockUntil: (data['stockUntil'] as Timestamp?)?.toDate(),
    );
  }
}

/// Price list and bKash details shown on the web premium page (`appConfig/premium`).
class PremiumConfigModel {
  final double monthlyPrice;
  final double yearlyPrice;
  final String bkashNumber;
  final String instructions;

  const PremiumConfigModel({
    this.monthlyPrice = 0,
    this.yearlyPrice = 0,
    this.bkashNumber = '',
    this.instructions = '',
  });

  bool get isReady => monthlyPrice > 0 && bkashNumber.isNotEmpty;

  double priceFor(int months) => months == 12 && yearlyPrice > 0 ? yearlyPrice : monthlyPrice * months;

  factory PremiumConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return PremiumConfigModel(
      monthlyPrice: (data['monthlyPrice'] as num?)?.toDouble() ?? 0,
      yearlyPrice: (data['yearlyPrice'] as num?)?.toDouble() ?? 0,
      bkashNumber: data['bkashNumber'] ?? '',
      instructions: data['instructions'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'monthlyPrice': monthlyPrice,
      'yearlyPrice': yearlyPrice,
      'bkashNumber': bkashNumber,
      'instructions': instructions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// A shop owner's bKash payment, waiting for the admin to check it.
class PremiumRequestModel {
  final String id;
  final String shopId;
  final String shopName;
  final String uid;
  final String userName;
  final String email;
  final String addon;
  final int months;
  final double amount;
  final String trxId;
  final String senderNumber;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final DateTime? reviewedAt;

  PremiumRequestModel({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.uid,
    required this.userName,
    required this.email,
    this.addon = 'stock',
    required this.months,
    required this.amount,
    required this.trxId,
    required this.senderNumber,
    this.status = 'pending',
    required this.createdAt,
    this.reviewedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';

  factory PremiumRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PremiumRequestModel(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      shopName: data['shopName'] ?? '',
      uid: data['uid'] ?? '',
      userName: data['userName'] ?? '',
      email: data['email'] ?? '',
      addon: data['addon'] ?? 'stock',
      months: (data['months'] as num?)?.toInt() ?? 1,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      trxId: data['trxId'] ?? '',
      senderNumber: data['senderNumber'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'shopName': shopName,
      'uid': uid,
      'userName': userName,
      'email': email,
      'addon': addon,
      'months': months,
      'amount': amount,
      'trxId': trxId,
      'senderNumber': senderNumber,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
