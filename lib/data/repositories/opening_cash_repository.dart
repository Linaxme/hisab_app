import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/opening_cash_model.dart';

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
