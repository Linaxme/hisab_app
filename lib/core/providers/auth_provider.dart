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
  Future<void> updateUserProfile(String uid, {String? name}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    updates['updatedAt'] = FieldValue.serverTimestamp();
    
    await firestore.collection('users').doc(uid).update(updates);
  }

  /// Update user name
  Future<void> updateUserName(String uid, String name) async {
    await firestore.collection('users').doc(uid).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
  Future<void> updateUserStatus(String uid, bool active) async {
    await firestore.collection('users').doc(uid).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
}
