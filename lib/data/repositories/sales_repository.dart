import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deposit_model.dart';
import '../models/sale_model.dart';

class SalesRepository {
  final FirebaseFirestore _firestore;
  final String shopId;

  SalesRepository({
    required this.shopId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _salesCollection =>
      _firestore.collection('shops').doc(shopId).collection('sales');

  CollectionReference<Map<String, dynamic>> get _depositsCollection =>
      _firestore.collection('shops').doc(shopId).collection('deposits');

  // Create (with the auto-deposit for a non-cash sale, written atomically)
  Future<String> addSale(SaleModel sale, {DepositModel? autoDeposit}) async {
    final batch = _firestore.batch();
    final saleRef = _salesCollection.doc();
    batch.set(saleRef, sale.toFirestore());
    if (autoDeposit != null) {
      batch.set(
        _depositsCollection.doc(),
        autoDeposit.copyWith(isAutoCreated: true, saleId: saleRef.id).toFirestore(),
      );
    }
    await batch.commit();
    return saleRef.id;
  }

  /// Auto-deposits belonging to [sale]. Deposits created before sales were
  /// linked have no saleId, so fall back to matching date and amount.
  Future<List<DocumentReference<Map<String, dynamic>>>> _linkedDepositRefs(
    SaleModel sale,
  ) async {
    final linked = await _depositsCollection
        .where('saleId', isEqualTo: sale.id)
        .get();
    if (linked.docs.isNotEmpty) {
      return linked.docs.map((d) => d.reference).toList();
    }
    if (sale.isCash) return [];

    final sameDay = await _depositsCollection
        .where('date', isEqualTo: sale.date)
        .get();
    final legacy = sameDay.docs.where((d) {
      final data = d.data();
      return data['isAutoCreated'] == true &&
          data['saleId'] == null &&
          (data['amount'] ?? 0).toDouble() == sale.sellPrice;
    });
    return legacy.isEmpty ? [] : [legacy.first.reference];
  }

  // Read - Stream for real-time updates
  Stream<List<SaleModel>> watchSalesByDate(String date) {
    return _salesCollection
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
          final sales = snapshot.docs.map((doc) => SaleModel.fromFirestore(doc)).toList();
          // Sort client-side to avoid composite index requirement
          sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return sales;
        });
  }

  // Read - Single fetch
  Future<List<SaleModel>> getSalesByDate(String date) async {
    final snapshot = await _salesCollection
        .where('date', isEqualTo: date)
        .get();
    final sales = snapshot.docs.map((doc) => SaleModel.fromFirestore(doc)).toList();
    sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sales;
  }

  // Read - Date range for reports
  Future<List<SaleModel>> getSalesByDateRange(String startDate, String endDate) async {
    final snapshot = await _salesCollection
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
    final sales = snapshot.docs.map((doc) => SaleModel.fromFirestore(doc)).toList();
    sales.sort((a, b) => b.date.compareTo(a.date));
    return sales;
  }

  // Update. [autoDeposit] is the deposit the sale should have now (null for a cash sale).
  Future<void> updateSale(
    SaleModel oldSale,
    SaleModel sale, {
    DepositModel? autoDeposit,
  }) async {
    final depositRefs = await _linkedDepositRefs(oldSale);
    final batch = _firestore.batch();
    batch.update(_salesCollection.doc(sale.id), sale.toUpdateFirestore());

    if (autoDeposit == null) {
      for (final ref in depositRefs) {
        batch.delete(ref);
      }
    } else if (depositRefs.isEmpty) {
      batch.set(
        _depositsCollection.doc(),
        autoDeposit.copyWith(isAutoCreated: true, saleId: sale.id).toFirestore(),
      );
    } else {
      batch.update(depositRefs.first, {
        ...autoDeposit.toUpdateFirestore(),
        'saleId': sale.id,
      });
      for (final ref in depositRefs.skip(1)) {
        batch.delete(ref);
      }
    }

    await batch.commit();
  }

  // Delete the sale together with its auto-deposit
  Future<void> deleteSale(SaleModel sale) async {
    final depositRefs = await _linkedDepositRefs(sale);
    final batch = _firestore.batch();
    batch.delete(_salesCollection.doc(sale.id));
    for (final ref in depositRefs) {
      batch.delete(ref);
    }
    await batch.commit();
  }

  // Get totals for a date
  Future<Map<String, double>> getDayTotals(String date) async {
    final sales = await getSalesByDate(date);
    
    double totalSales = 0;
    double totalProfit = 0;
    double cashSales = 0;
    double nonCashSales = 0;

    for (final sale in sales) {
      totalSales += sale.sellPrice;
      totalProfit += sale.profit;
      if (sale.isCash) {
        cashSales += sale.sellPrice;
      } else {
        nonCashSales += sale.sellPrice;
      }
    }

    return {
      'totalSales': totalSales,
      'totalProfit': totalProfit,
      'cashSales': cashSales,
      'nonCashSales': nonCashSales,
    };
  }
}
