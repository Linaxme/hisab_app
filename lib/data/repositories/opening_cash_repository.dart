import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/opening_cash_model.dart';
import '../models/sale_model.dart';

class OpeningCashRepository {
  final FirebaseFirestore _firestore;
  final String shopId;

  OpeningCashRepository({
    required this.shopId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _shopCollection(String name) =>
      _firestore.collection('shops').doc(shopId).collection(name);

  CollectionReference<Map<String, dynamic>> get _openingCashCollection => _shopCollection('openingCash');

  CollectionReference<Map<String, dynamic>> get _cashChecks => _shopCollection('cashChecks');

  /// Saves a count. A non-zero [CashCheckModel.adjustment] is booked with it:
  /// an excess as a cash sale named [saleLabel], a shortage as a cash expense
  /// named [expenseLabel].
  Future<void> addCashCheck(
    CashCheckModel check, {
    String saleLabel = '',
    String expenseLabel = '',
  }) async {
    final batch = _firestore.batch();
    String? adjustmentId;
    if (check.adjustment > 0) {
      final ref = _shopCollection('sales').doc();
      adjustmentId = ref.id;
      batch.set(
        ref,
        SaleModel(
          id: '',
          productName: saleLabel,
          sellPrice: check.adjustment,
          profit: 0,
          paymentType: PaymentType.cash,
          date: check.date,
          createdBy: check.createdBy,
          createdAt: DateTime.now(),
          isAdjustment: true,
        ).toFirestore(),
      );
    } else if (check.adjustment < 0) {
      final ref = _shopCollection('expenses').doc();
      adjustmentId = ref.id;
      batch.set(
        ref,
        ExpenseModel(
          id: '',
          amount: -check.adjustment,
          categoryId: '',
          categoryName: expenseLabel,
          paymentType: PaymentType.cash,
          date: check.date,
          createdBy: check.createdBy,
          createdAt: DateTime.now(),
        ).toFirestore(),
      );
    }
    batch.set(_cashChecks.doc(), {
      ...check.toFirestore(),
      if (adjustmentId != null) 'adjustmentId': adjustmentId,
    });
    await batch.commit();
  }

  /// Deletes a count and the sale or expense it booked.
  Future<void> deleteCashCheck(CashCheckModel check) async {
    final batch = _firestore.batch();
    batch.delete(_cashChecks.doc(check.id));
    final adjustmentId = check.adjustmentId;
    if (adjustmentId != null) {
      batch.delete(_shopCollection(check.adjustment < 0 ? 'expenses' : 'sales').doc(adjustmentId));
    }
    await batch.commit();
  }

  /// The day's drawer counts, latest first.
  Stream<List<CashCheckModel>> watchCashChecks(String date) {
    return _cashChecks.where('date', isEqualTo: date).snapshots().map((snapshot) {
      final checks = snapshot.docs.map(CashCheckModel.fromFirestore).toList();
      checks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return checks;
    });
  }

  Future<List<CashCheckModel>> getCashChecksByDateRange(String startDate, String endDate) async {
    final snapshot = await _cashChecks
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
    return snapshot.docs.map(CashCheckModel.fromFirestore).toList();
  }

  // Set or update opening cash for a date. A hand-set amount stops following
  // the previous day's end cash.
  Future<void> setOpeningCash(String date, double amount, String createdBy) async {
    final docRef = _openingCashCollection.doc(date);
    final doc = await docRef.get();
    
    if (doc.exists) {
      await docRef.update({
        'amount': amount,
        'carriedFrom': FieldValue.delete(),
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

  /// Makes a hand-set opening follow the previous day's end cash again.
  Future<void> followPreviousDay(String date) async {
    await _openingCashCollection.doc(date).update({
      'carriedFrom': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sets [date]'s opening to [amount] carried from [fromDate] ('' for none).
  Future<void> setCarriedOpening(
    String date, {
    required double amount,
    required String fromDate,
    required bool exists,
    required String createdBy,
  }) async {
    final docRef = _openingCashCollection.doc(date);
    if (exists) {
      await docRef.update({
        'amount': amount,
        'carriedFrom': fromDate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.set({
        'amount': amount,
        'carriedFrom': fromDate,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
      });
    }
  }

  /// The latest opening document before [date], if any.
  Future<OpeningCashModel?> getLatestBefore(String date) async {
    final snapshot = await _openingCashCollection
        .where(FieldPath.documentId, isLessThan: date)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : OpeningCashModel.fromFirestore(snapshot.docs.first);
  }

  /// Opening documents after [date], oldest first.
  Future<List<OpeningCashModel>> getOpeningsAfter(String date, {int limit = 62}) async {
    final snapshot = await _openingCashCollection
        .where(FieldPath.documentId, isGreaterThan: date)
        .orderBy(FieldPath.documentId)
        .limit(limit)
        .get();
    return snapshot.docs.map(OpeningCashModel.fromFirestore).toList();
  }

  // Get opening cash for a date
  Future<OpeningCashModel?> getOpeningCash(String date) async {
    final doc = await _openingCashCollection.doc(date).get();
    if (doc.exists) {
      return OpeningCashModel.fromFirestore(doc);
    }
    return null;
  }

  // Opening cash / day-close documents for a date range (ids are dates)
  Future<List<OpeningCashModel>> getOpeningCashByDateRange(String startDate, String endDate) async {
    final snapshot = await _openingCashCollection
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDate)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endDate)
        .get();
    return snapshot.docs.map((doc) => OpeningCashModel.fromFirestore(doc)).toList();
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
