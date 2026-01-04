import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/return_model.dart';

class ReturnsRepository {
  final FirebaseFirestore _firestore;
  final String shopId;

  ReturnsRepository({
    required this.shopId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _returnsCollection =>
      _firestore.collection('shops').doc(shopId).collection('returns');

  // Create
  Future<String> addReturn(ReturnModel returnItem) async {
    final docRef = await _returnsCollection.add(returnItem.toFirestore());
    return docRef.id;
  }

  // Read - Stream for real-time updates
  Stream<List<ReturnModel>> watchReturnsByDate(String date) {
    return _returnsCollection
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
          final returns = snapshot.docs.map((doc) => ReturnModel.fromFirestore(doc)).toList();
          returns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return returns;
        });
  }

  // Read - Single fetch
  Future<List<ReturnModel>> getReturnsByDate(String date) async {
    final snapshot = await _returnsCollection
        .where('date', isEqualTo: date)
        .get();
    final returns = snapshot.docs.map((doc) => ReturnModel.fromFirestore(doc)).toList();
    returns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return returns;
  }

  // Read - Date range for reports
  Future<List<ReturnModel>> getReturnsByDateRange(String startDate, String endDate) async {
    final snapshot = await _returnsCollection
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
    final returns = snapshot.docs.map((doc) => ReturnModel.fromFirestore(doc)).toList();
    returns.sort((a, b) => b.date.compareTo(a.date));
    return returns;
  }

  // Update
  Future<void> updateReturn(ReturnModel returnItem) async {
    await _returnsCollection.doc(returnItem.id).update(returnItem.toUpdateFirestore());
  }

  // Delete
  Future<void> deleteReturn(String returnId) async {
    await _returnsCollection.doc(returnId).delete();
  }

  // Get total for a date
  Future<double> getDayTotal(String date) async {
    final returns = await getReturnsByDate(date);
    return returns.fold<double>(0.0, (sum, r) => sum + r.amount);
  }
}
