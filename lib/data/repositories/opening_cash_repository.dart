import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/opening_cash_model.dart';
import '../models/sale_model.dart';

class OpeningCashRepository {
  final FirebaseFirestore _firestore;
  final String shopId;

  OpeningCashRepository({
    required this.shopId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _openingCashCollection =>
      _firestore.collection('shops').doc(shopId).collection('openingCash');

  // Set or update opening cash for a date
  Future<void> setOpeningCash(String date, double amount, String createdBy) async {
    final docRef = _openingCashCollection.doc(date);
    final doc = await docRef.get();
    
    if (doc.exists) {
      await docRef.update({
        'amount': amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.set({
        'amount': amount,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
      });
    }
  }

  /// Records the end-of-day drawer count on [date]'s document and, when
  /// [nextDate] is given, carries the counted cash over as that day's opening.
  ///
  /// An [adjustment] above zero books the excess cash as a sale on [date],
  /// reusing [existingAdjustmentId] from an earlier count when there is one;
  /// a zero [adjustment] removes that earlier adjustment sale.
  Future<void> closeDay({
    required String date,
    required double expected,
    required double counted,
    required String closedBy,
    String? nextDate,
    double adjustment = 0,
    String adjustmentLabel = '',
    String? existingAdjustmentId,
  }) async {
    final docRef = _openingCashCollection.doc(date);
    final doc = await docRef.get();
    final closing = {
      'closingExpected': expected,
      'closingCounted': counted,
      'closingAdjustment': adjustment,
      'closedBy': closedBy,
      'closedAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    if (doc.exists) {
      batch.update(docRef, closing);
    } else {
      batch.set(docRef, {
        'amount': 0.0,
        'createdBy': closedBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
        ...closing,
      });
    }

    final sales = _firestore.collection('shops').doc(shopId).collection('sales');
    if (adjustment > 0 && existingAdjustmentId != null) {
      batch.update(sales.doc(existingAdjustmentId), {
        'sellPrice': adjustment,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (adjustment > 0) {
      batch.set(
        sales.doc(),
        SaleModel(
          id: '',
          productName: adjustmentLabel,
          sellPrice: adjustment,
          profit: 0,
          paymentType: PaymentType.cash,
          date: date,
          createdBy: closedBy,
          createdAt: DateTime.now(),
          isAdjustment: true,
        ).toFirestore(),
      );
    } else if (existingAdjustmentId != null) {
      batch.delete(sales.doc(existingAdjustmentId));
    }
    await batch.commit();

    if (nextDate != null) {
      await setOpeningCash(nextDate, counted, closedBy);
    }
  }

  // Get opening cash for a date
  Future<OpeningCashModel?> getOpeningCash(String date) async {
    final doc = await _openingCashCollection.doc(date).get();
    if (doc.exists) {
      return OpeningCashModel.fromFirestore(doc);
    }
    return null;
  }

  // Watch opening cash for a date
  Stream<OpeningCashModel?> watchOpeningCash(String date) {
    return _openingCashCollection.doc(date).snapshots().map((doc) {
      if (doc.exists) {
        return OpeningCashModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Get opening cash amount for a date (returns 0 if not set)
  Future<double> getOpeningCashAmount(String date) async {
    final openingCash = await getOpeningCash(date);
    return openingCash?.amount ?? 0;
  }
}
