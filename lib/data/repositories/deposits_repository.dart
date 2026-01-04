import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deposit_model.dart';

class DepositsRepository {
  final FirebaseFirestore _firestore;
  final String shopId;

  DepositsRepository({
    required this.shopId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _depositsCollection =>
      _firestore.collection('shops').doc(shopId).collection('deposits');

  // Create
  Future<String> addDeposit(DepositModel deposit) async {
    final docRef = await _depositsCollection.add(deposit.toFirestore());
    return docRef.id;
  }

  // Read - Stream for real-time updates
  Stream<List<DepositModel>> watchDepositsByDate(String date) {
    return _depositsCollection
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
          final deposits = snapshot.docs.map((doc) => DepositModel.fromFirestore(doc)).toList();
          deposits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return deposits;
        });
  }

  // Read - Single fetch
  Future<List<DepositModel>> getDepositsByDate(String date) async {
    final snapshot = await _depositsCollection
        .where('date', isEqualTo: date)
        .get();
    final deposits = snapshot.docs.map((doc) => DepositModel.fromFirestore(doc)).toList();
    deposits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deposits;
  }

  // Read - Date range for reports
  Future<List<DepositModel>> getDepositsByDateRange(String startDate, String endDate) async {
    final snapshot = await _depositsCollection
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
    final deposits = snapshot.docs.map((doc) => DepositModel.fromFirestore(doc)).toList();
    deposits.sort((a, b) => b.date.compareTo(a.date));
    return deposits;
  }

  // Update
  Future<void> updateDeposit(DepositModel deposit) async {
    await _depositsCollection.doc(deposit.id).update(deposit.toUpdateFirestore());
  }

  // Delete
  Future<void> deleteDeposit(String depositId) async {
    await _depositsCollection.doc(depositId).delete();
  }

  // Get total for a date
  Future<double> getDayTotal(String date) async {
    final deposits = await getDepositsByDate(date);
    return deposits.fold<double>(0.0, (sum, deposit) => sum + deposit.amount);
  }

  // Get total for manual deposits only (for Live Cash calculation)
  Future<double> getManualDepositsDayTotal(String date) async {
    final deposits = await getDepositsByDate(date);
    return deposits
        .where((deposit) => !deposit.isAutoCreated)
        .fold<double>(0.0, (sum, deposit) => sum + deposit.amount);
  }
}
