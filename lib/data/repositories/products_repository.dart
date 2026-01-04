import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductsRepository {
  final String shopId;
  final FirebaseFirestore _firestore;

  ProductsRepository({
    required this.shopId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection =>
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
}
