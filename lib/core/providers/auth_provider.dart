import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/models.dart';
import 'firebase_providers.dart';

/// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

/// Alias for auth repository (used for user management)
final userRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref.watch(authRepositoryProvider);
});

/// Current user data provider (Firestore user document)
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final firestore = ref.watch(firestoreProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        return UserModel.fromFirestore(doc);
      });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

/// Current shop provider
final currentShopProvider = StreamProvider<ShopModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);

  return userAsync.when(
    data: (user) {
      if (user == null || user.shopId == null) return Stream.value(null);
      return firestore
          .collection('shops')
          .doc(user.shopId)
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        return ShopModel.fromFirestore(doc);
      });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

/// Auth Repository class
class AuthRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  AuthRepository({required this.auth, required this.firestore});

  User? get currentUser => auth.currentUser;

  DocumentReference<Map<String, dynamic>> memberRef(String shopId, String uid) =>
      firestore.collection('shops').doc(shopId).collection('members').doc(uid);

  /// Writes [user] into the shop's member list; [isNew] also stamps the join time.
  Future<void> upsertMember(String shopId, UserModel user, {bool isNew = false}) async {
    await memberRef(shopId, user.uid).set({
      ...MemberModel.fieldsOf(user),
      if (isNew) 'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Member-list updates are a copy of `users`; the shop sync repairs any that fail.
  Future<void> _tryUpdateMember(String? shopId, String uid, Map<String, dynamic> fields) async {
    if (shopId == null) return;
    try {
      await memberRef(shopId, uid).update({...fields, 'updatedAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (_) {}
  }

  /// Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await auth.signOut();
  }

  /// Create user document in Firestore
  Future<void> createUserDocument({
    required String uid,
    required String email,
    required String name,
    required String role,
    String? shopId,
  }) async {
    final user = UserModel(
      uid: uid,
      email: email,
      name: name,
      role: role,
      shopId: shopId,
      active: true,
      createdAt: DateTime.now(),
    );

    await firestore.collection('users').doc(uid).set(user.toFirestore());
  }

  /// Update user's shop ID
  Future<void> updateUserShopId(String uid, String shopId, {String? joinCode}) async {
    await firestore.collection('users').doc(uid).update({
      'shopId': shopId,
      if (joinCode != null) 'joinCode': joinCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update user profile
  Future<void> updateUserProfile(String uid, {String? name, String? shopId}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    updates['updatedAt'] = FieldValue.serverTimestamp();
    
    await firestore.collection('users').doc(uid).update(updates);
    if (name != null) await _tryUpdateMember(shopId, uid, {'name': name});
  }

  /// Update user name
  Future<void> updateUserName(String uid, String name, {String? shopId}) async {
    await firestore.collection('users').doc(uid).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _tryUpdateMember(shopId, uid, {'name': name});
  }

  /// Get user by UID
  Future<UserModel?> getUserById(String uid) async {
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Watch staff members by shop ID
  Stream<List<UserModel>> watchStaffByShopId(String shopId) {
    return firestore
        .collection('users')
        .where('shopId', isEqualTo: shopId)
        .where('role', isEqualTo: 'staff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  /// Update user active status
  Future<void> updateUserStatus(String uid, bool active, {String? shopId}) async {
    await firestore.collection('users').doc(uid).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _tryUpdateMember(shopId, uid, {'active': active});
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No user logged in');
    }

    // Re-authenticate user with current password
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    
    await user.reauthenticateWithCredential(credential);
    
    // Update password
    await user.updatePassword(newPassword);
  }

  static const _shopSubcollections = [
    'sales',
    'expenses',
    'deposits',
    'returns',
    'creditSales',
    'creditCollections',
    'products',
    'openingCash',
    'stockEntries',
    'cashChecks',
    'members',
  ];
  static const _deleteChunk = 200;
  static const _server = GetOptions(source: Source.server);

  /// Permanently delete the signed-in account. When a shop owner deletes their
  /// account, the shop and every record in it are deleted and staff are
  /// detached. A staff member's own entries stay with the shop.
  Future<void> deleteAccount({required String password}) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No user logged in');
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );

    final userRef = firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get(_server);
    final data = userDoc.data();
    final shopId = data?['shopId'] as String?;

    if (data?['role'] == 'owner' && shopId != null) {
      final shopRef = firestore.collection('shops').doc(shopId);
      final shopDoc = await shopRef.get(_server);
      if (shopDoc.exists && shopDoc.data()?['ownerUid'] == user.uid) {
        await _deleteShop(shopRef, shopDoc.data()?['inviteCode'] as String?);
      }
    } else if (shopId != null) {
      try {
        await memberRef(shopId, user.uid).delete();
      } on FirebaseException catch (_) {}
    }

    if (userDoc.exists) await userRef.delete();
    await user.delete();
  }

  Future<void> _deleteShop(
    DocumentReference<Map<String, dynamic>> shopRef,
    String? inviteCode,
  ) async {
    final staff = await firestore
        .collection('users')
        .where('shopId', isEqualTo: shopRef.id)
        .where('role', isEqualTo: 'staff')
        .get(_server);
    for (var i = 0; i < staff.docs.length; i += _deleteChunk) {
      final batch = firestore.batch();
      for (final doc in staff.docs.skip(i).take(_deleteChunk)) {
        batch.update(doc.reference, {
          'shopId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    final categories = await shopRef.collection('expenseCategories').get(_server);
    for (final category in categories.docs) {
      await _deleteAll(category.reference.collection('subcategories'));
    }
    await _deleteAll(shopRef.collection('expenseCategories'));
    for (final name in _shopSubcollections) {
      await _deleteAll(shopRef.collection(name));
    }

    if (inviteCode != null && inviteCode.isNotEmpty) {
      final codeRef = firestore.collection('inviteCodes').doc(inviteCode);
      final codeDoc = await codeRef.get(_server);
      if (codeDoc.data()?['shopId'] == shopRef.id) await codeRef.delete();
    }
    await shopRef.delete();
  }

  Future<void> _deleteAll(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(_deleteChunk).get(_server);
      if (snapshot.docs.isEmpty) return;

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      try {
        await batch.commit();
      } on FirebaseException catch (e) {
        // Large batches can exceed the rules' per-request document-access limit.
        if (e.code != 'permission-denied') rethrow;
        await Future.wait(snapshot.docs.map((doc) => doc.reference.delete()));
      }
      if (snapshot.docs.length < _deleteChunk) return;
    }
  }
}
