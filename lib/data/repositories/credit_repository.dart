import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/credit_model.dart';

class CreditRepository {
  final FirebaseFirestore _firestore;
  final String shopId;

  CreditRepository({
    required this.shopId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _creditSalesCollection =>
      _firestore.collection('shops').doc(shopId).collection('creditSales');

  CollectionReference<Map<String, dynamic>> get _collectionsCollection =>
      _firestore.collection('shops').doc(shopId).collection('creditCollections');

  // ============ CREDIT SALES ============

  // Create credit sale
  Future<String> addCreditSale(CreditSaleModel creditSale) async {
    final docRef = await _creditSalesCollection.add(creditSale.toFirestore());
    return docRef.id;
  }

  // Watch all credit sales (with pending filter option)
  Stream<List<CreditSaleModel>> watchCreditSales({bool pendingOnly = false}) {
    return _creditSalesCollection.snapshots().map((snapshot) {
      var sales = snapshot.docs
          .map((doc) => CreditSaleModel.fromFirestore(doc))
          .toList();
      
      // Sort client-side
      sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      if (pendingOnly) {
        sales = sales.where((s) => !s.isFullyPaid).toList();
      }
      
      return sales;
    });
  }

  // Get credit sales by date
  Stream<List<CreditSaleModel>> watchCreditSalesByDate(String date) {
    return _creditSalesCollection
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
          final sales = snapshot.docs.map((doc) => CreditSaleModel.fromFirestore(doc)).toList();
          sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return sales;
        });
  }

  // Get single credit sale
  Future<CreditSaleModel?> getCreditSale(String id) async {
    final doc = await _creditSalesCollection.doc(id).get();
    if (doc.exists) {
      return CreditSaleModel.fromFirestore(doc);
    }
    return null;
  }

  // Watch single credit sale
  Stream<CreditSaleModel?> watchCreditSale(String id) {
    return _creditSalesCollection.doc(id).snapshots().map(
          (doc) => doc.exists ? CreditSaleModel.fromFirestore(doc) : null,
        );
  }

  // A few credit sales with this exact phone or name, to spot an existing customer
  Future<List<CreditSaleModel>> findCreditSales({String? phone, String? name}) async {
    final field = phone != null ? 'customerPhone' : 'customerName';
    final snapshot = await _creditSalesCollection
        .where(field, isEqualTo: phone ?? name)
        .limit(5)
        .get();
    return snapshot.docs.map((doc) => CreditSaleModel.fromFirestore(doc)).toList();
  }

  // Update credit sale
  Future<void> updateCreditSale(CreditSaleModel creditSale) async {
    await _creditSalesCollection.doc(creditSale.id).update(creditSale.toUpdateFirestore());
  }

  // Delete credit sale (and its collections)
  Future<void> deleteCreditSale(String creditSaleId) async {
    // Delete the credit sale and all its collections atomically
    final collectionsSnapshot = await _collectionsCollection
        .where('creditSaleId', isEqualTo: creditSaleId)
        .get();
    
    final batch = _firestore.batch();
    for (final doc in collectionsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_creditSalesCollection.doc(creditSaleId));
    await batch.commit();
  }

  // ============ CREDIT COLLECTIONS ============

  // Add collection and update credit sale's collected amount atomically
  Future<String> addCollection(CreditCollectionModel collection) async {
    final batch = _firestore.batch();
    final docRef = _collectionsCollection.doc();
    batch.set(docRef, collection.toFirestore());
    batch.update(_creditSalesCollection.doc(collection.creditSaleId), {
      'collectedAmount': FieldValue.increment(collection.amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    
    return docRef.id;
  }

  // Watch collections for a credit sale
  Stream<List<CreditCollectionModel>> watchCollectionsForSale(String creditSaleId) {
    return _collectionsCollection
        .where('creditSaleId', isEqualTo: creditSaleId)
        .snapshots()
        .map((snapshot) {
          final collections = snapshot.docs.map((doc) => CreditCollectionModel.fromFirestore(doc)).toList();
          collections.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return collections;
        });
  }

  // Watch collections by date
  Stream<List<CreditCollectionModel>> watchCollectionsByDate(String date) {
    return _collectionsCollection
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
          final collections = snapshot.docs.map((doc) => CreditCollectionModel.fromFirestore(doc)).toList();
          collections.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return collections;
        });
  }

  // Delete collection (and update credit sale's collected amount)
  Future<void> deleteCollection(String collectionId, String creditSaleId, double amount) async {
    final batch = _firestore.batch();
    batch.delete(_collectionsCollection.doc(collectionId));
    batch.update(_creditSalesCollection.doc(creditSaleId), {
      'collectedAmount': FieldValue.increment(-amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ============ SUMMARY ============

  // Credit summary via aggregate queries: one read per 1000 credit sales instead of one per sale
  Future<Map<String, double>> getCreditSummaryAggregate() async {
    // Separate queries so each runs on the automatic single-field index.
    final results = await Future.wait([
      _creditSalesCollection.aggregate(sum('amount')).get(),
      _creditSalesCollection.aggregate(sum('collectedAmount')).get(),
    ]);
    final totalCredit = results[0].getSum('amount') ?? 0;
    final totalCollected = results[1].getSum('collectedAmount') ?? 0;
    return {
      'totalCredit': totalCredit,
      'totalCollected': totalCollected,
      'remaining': totalCredit - totalCollected,
    };
  }

  // Get credit summary
  Future<Map<String, double>> getCreditSummary() async {
    final snapshot = await _creditSalesCollection.get();
    final creditSales = snapshot.docs
        .map((doc) => CreditSaleModel.fromFirestore(doc))
        .toList();

    double totalCredit = 0;
    double totalCollected = 0;

    for (final sale in creditSales) {
      totalCredit += sale.amount;
      totalCollected += sale.collectedAmount;
    }

    return {
      'totalCredit': totalCredit,
      'totalCollected': totalCollected,
      'remaining': totalCredit - totalCollected,
    };
  }

  // Get total collections for a specific date
  Future<double> getCollectionsByDate(String date) async {
    final snapshot = await _collectionsCollection
        .where('date', isEqualTo: date)
        .get();
    
    double total = 0;
    for (final doc in snapshot.docs) {
      final collection = CreditCollectionModel.fromFirestore(doc);
      total += collection.amount;
    }
    
    return total;
  }
}
