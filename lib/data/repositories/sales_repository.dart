import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Create
  Future<String> addSale(SaleModel sale) async {
    final docRef = await _salesCollection.add(sale.toFirestore());
    return docRef.id;
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

  // Update
  Future<void> updateSale(SaleModel sale) async {
    await _salesCollection.doc(sale.id).update(sale.toUpdateFirestore());
  }

  // Delete
  Future<void> deleteSale(String saleId) async {
    await _salesCollection.doc(saleId).delete();
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
