import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductsRepository {
  final String shopId;
  final FirebaseFirestore _firestore;

  ProductsRepository({
    required this.shopId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(shopId).collection('products');

  /// Add a new product
  Future<String> addProduct(String name) async {
    final product = ProductModel(
      id: '',
      name: name,
      active: true,
      createdAt: DateTime.now(),
    );

    final docRef = await _collection.add(product.toFirestore());
    return docRef.id;
  }

  /// Update product
  Future<void> updateProduct(String productId, String name) async {
    await _collection.doc(productId).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete product (soft delete)
  Future<void> deleteProduct(String productId) async {
    await _collection.doc(productId).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Watch all active products
  Stream<List<ProductModel>> watchProducts() {
    return _collection
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();
      // Sort client-side to avoid Firestore index requirement
      products.sort((a, b) => a.name.compareTo(b.name));
      return products;
    });
  }

  /// Get all active products
  Future<List<ProductModel>> getProducts() async {
    final snapshot = await _collection
        .where('active', isEqualTo: true)
        .get();

    final products = snapshot.docs
        .map((doc) => ProductModel.fromFirestore(doc))
        .toList();
    // Sort client-side to avoid Firestore index requirement
    products.sort((a, b) => a.name.compareTo(b.name));
    return products;
  }

  // ============ STOCK (add-on) ============

  CollectionReference<Map<String, dynamic>> get _stockEntries =>
      _firestore.collection('shops').doc(shopId).collection('stockEntries');

  /// Adds a product that is stock-tracked from the start, with [product]'s quantity.
  Future<String> addStockProduct(ProductModel product, {required String createdBy, required String date}) async {
    final batch = _firestore.batch();
    final ref = _collection.doc();
    batch.set(ref, ProductModel(
      id: '',
      name: product.name,
      createdAt: DateTime.now(),
      trackStock: true,
      unit: product.unit,
      buyPrice: product.buyPrice,
      sellPrice: product.sellPrice,
      lowStockAt: product.lowStockAt,
    ).toFirestore());
    if (product.stockQty != 0) {
      batch.update(ref, {'stockQty': product.stockQty});
      batch.set(_stockEntries.doc(), StockEntryModel(
        id: '',
        productId: ref.id,
        productName: product.name,
        type: 'adjust',
        quantity: product.stockQty,
        date: date,
        createdBy: createdBy,
        createdAt: DateTime.now(),
      ).toFirestore());
    }
    await batch.commit();
    return ref.id;
  }

  /// Saves the name and stock settings; the quantity is left alone.
  Future<void> updateStockSettings(ProductModel product) async {
    await _collection.doc(product.id).update({
      'name': product.name,
      ...product.stockFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Records goods received (or a correction) and moves the product's stock by its quantity.
  Future<void> addStockEntry(StockEntryModel entry) async {
    final batch = _firestore.batch();
    batch.set(_stockEntries.doc(), entry.toFirestore());
    batch.update(_collection.doc(entry.productId), {
      'stockQty': FieldValue.increment(entry.quantity),
      if (entry.buyPrice != null && !entry.isAdjustment) 'buyPrice': entry.buyPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Sets the stock to what was actually counted, logged as a correction.
  Future<void> setStockCount(ProductModel product, double counted,
      {required String createdBy, required String date, String? note}) async {
    final delta = counted - product.stockQty;
    if (delta == 0) return;
    await addStockEntry(StockEntryModel(
      id: '',
      productId: product.id,
      productName: product.name,
      type: 'adjust',
      quantity: delta,
      note: note,
      date: date,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    ));
  }

  /// Removes an entry and takes its quantity back out of stock.
  Future<void> deleteStockEntry(StockEntryModel entry) async {
    final batch = _firestore.batch();
    batch.delete(_stockEntries.doc(entry.id));
    batch.update(_collection.doc(entry.productId), {
      'stockQty': FieldValue.increment(-entry.quantity),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Stock movements of one product, newest first.
  Stream<List<StockEntryModel>> watchStockEntries(String productId) {
    return _stockEntries.where('productId', isEqualTo: productId).snapshots().map((snapshot) {
      final entries = snapshot.docs.map((doc) => StockEntryModel.fromFirestore(doc)).toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    });
  }
}
