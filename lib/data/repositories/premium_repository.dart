import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/premium_model.dart';

/// Paid add-ons: each shop's status, bKash payment requests and the price list.
class PremiumRepository {
  final FirebaseFirestore _firestore;

  PremiumRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _shopPremium =>
      _firestore.collection('shopPremium');

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('premiumRequests');

  DocumentReference<Map<String, dynamic>> get _config =>
      _firestore.collection('appConfig').doc('premium');

  Stream<ShopPremiumModel> watchShopPremium(String shopId) {
    return _shopPremium.doc(shopId).snapshots().map(ShopPremiumModel.fromFirestore);
  }

  Stream<PremiumConfigModel> watchConfig() {
    return _config.snapshots().map(PremiumConfigModel.fromFirestore);
  }

  Future<void> saveConfig(PremiumConfigModel config) async {
    await _config.set(config.toFirestore());
  }

  Future<void> submitRequest(PremiumRequestModel request) async {
    await _requests.add(request.toFirestore());
  }

  /// The signed-in owner's own requests, newest first.
  Stream<List<PremiumRequestModel>> watchMyRequests(String uid) {
    return _requests.where('uid', isEqualTo: uid).snapshots().map(_sorted);
  }

  /// Admin: requests still waiting for a decision.
  Stream<List<PremiumRequestModel>> watchPendingRequests() {
    return _requests.where('status', isEqualTo: 'pending').snapshots().map(_sorted);
  }

  /// Admin: latest requests of any status.
  Stream<List<PremiumRequestModel>> watchRecentRequests({int limit = 50}) {
    return _requests
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_sorted);
  }

  static List<PremiumRequestModel> _sorted(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final requests = snapshot.docs.map(PremiumRequestModel.fromFirestore).toList();
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests;
  }

  /// Admin: approves a payment and extends the shop's Stock add-on by its months,
  /// counting from today or from the current end date, whichever is later.
  Future<DateTime> approve(PremiumRequestModel request) async {
    return _firestore.runTransaction((tx) async {
      final premiumRef = _shopPremium.doc(request.shopId);
      final current = ShopPremiumModel.fromFirestore(await tx.get(premiumRef));
      final now = DateTime.now();
      final from = current.stockUntil != null && current.stockUntil!.isAfter(now)
          ? current.stockUntil!
          : now;
      final until = DateTime(from.year, from.month + request.months, from.day, from.hour, from.minute);
      tx.set(
        premiumRef,
        {'stockUntil': Timestamp.fromDate(until), 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      tx.update(_requests.doc(request.id), {
        'status': 'approved',
        'grantedUntil': Timestamp.fromDate(until),
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      return until;
    });
  }

  /// Admin: marks a payment as not received.
  Future<void> reject(PremiumRequestModel request) async {
    await _requests.doc(request.id).update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }
}
