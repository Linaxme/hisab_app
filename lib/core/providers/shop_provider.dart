import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/models.dart';
import 'firebase_providers.dart';
import 'auth_provider.dart';

/// Shop Repository Provider
final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(
    firestore: ref.watch(firestoreProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

/// Keeps the owner's invite code registered in the inviteCodes lookup collection
final inviteCodeSyncProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final shop = ref.watch(currentShopProvider).valueOrNull;
  if (user == null || !user.isOwner || shop == null || shop.ownerUid != user.uid) {
    return;
  }
  await ref.read(shopRepositoryProvider).ensureInviteCodeRegistered(shop);
});

/// Shop Repository class
class ShopRepository {
  final FirebaseFirestore firestore;
  final AuthRepository authRepository;

  ShopRepository({required this.firestore, required this.authRepository});

  /// Generate random invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      firestore.collection('inviteCodes');

  /// Generate an invite code that is not already registered
  Future<String> _generateUnusedInviteCode() async {
    while (true) {
      final code = _generateInviteCode();
      final existing = await _inviteCodes.doc(code).get();
      if (!existing.exists) return code;
    }
  }

  /// Create a new shop (Owner only)
  Future<String> createShop({
    required String name,
    required String ownerUid,
  }) async {
    final inviteCode = await _generateUnusedInviteCode();
    
    final shop = ShopModel(
      id: '',
      name: name,
      inviteCode: inviteCode,
      ownerUid: ownerUid,
      createdAt: DateTime.now(),
    );

    final docRef = await firestore.collection('shops').add(shop.toFirestore());
    
    // Update user with shopId
    await authRepository.updateUserShopId(ownerUid, docRef.id);

    await _inviteCodes.doc(inviteCode).set({
      'shopId': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Create default expense categories
    await _createDefaultCategories(docRef.id);
    
    return docRef.id;
  }

  /// Join existing shop using invite code (Staff only)
  Future<String?> joinShop({
    required String inviteCode,
    required String userId,
  }) async {
    final code = inviteCode.trim().toUpperCase();
    final codeDoc = await _inviteCodes.doc(code).get();
    final shopId = codeDoc.data()?['shopId'] as String?;

    if (shopId == null) {
      return null; // Invalid invite code
    }
    
    // Update user with shopId; the security rules verify the code against inviteCodes
    await authRepository.updateUserShopId(userId, shopId, joinCode: code);
    
    return shopId;
  }

  /// Regenerate invite code (Owner only)
  Future<String> regenerateInviteCode(String shopId) async {
    final shop = await getShopById(shopId);
    final newCode = await _generateUnusedInviteCode();

    await _inviteCodes.doc(newCode).set({
      'shopId': shopId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    await firestore.collection('shops').doc(shopId).update({
      'inviteCode': newCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (shop != null && shop.inviteCode.isNotEmpty && shop.inviteCode != newCode) {
      final oldDoc = await _inviteCodes.doc(shop.inviteCode).get();
      if (oldDoc.data()?['shopId'] == shopId) {
        await oldDoc.reference.delete();
      }
    }
    
    return newCode;
  }

  /// Register the shop's current invite code in the lookup collection.
  /// Shops created before the inviteCodes collection existed need this once.
  Future<void> ensureInviteCodeRegistered(ShopModel shop) async {
    if (shop.inviteCode.isEmpty) {
      await regenerateInviteCode(shop.id);
      return;
    }

    final codeDoc = await _inviteCodes.doc(shop.inviteCode).get();
    if (!codeDoc.exists) {
      await _inviteCodes.doc(shop.inviteCode).set({
        'shopId': shop.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else if (codeDoc.data()?['shopId'] != shop.id) {
      await regenerateInviteCode(shop.id);
    }
  }

  /// Update shop settings
  Future<void> updateShopSettings(String shopId, {bool? showProfit}) async {
    final updates = <String, dynamic>{};
    if (showProfit != null) updates['showProfit'] = showProfit;
    updates['updatedAt'] = FieldValue.serverTimestamp();
    
    await firestore.collection('shops').doc(shopId).update(updates);
  }

  /// Update shop name
  Future<void> updateShopName(String shopId, String name) async {
    await firestore.collection('shops').doc(shopId).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get shop by ID
  Future<ShopModel?> getShopById(String shopId) async {
    final doc = await firestore.collection('shops').doc(shopId).get();
    if (!doc.exists) return null;
    return ShopModel.fromFirestore(doc);
  }

  /// Create default expense categories for a new shop
  Future<void> _createDefaultCategories(String shopId) async {
    final defaultCategories = [
      {
        'name': 'Shop Expense',
        'subcategories': ['Breakfast', 'Bag', 'Rent', 'Electricity', 'Generator', 'Other Bills', 'Staff Bill'],
      },
      {
        'name': 'Home Expense',
        'subcategories': <String>[],
      },
      {
        'name': 'Purchase',
        'subcategories': <String>[],
      },
      {
        'name': 'Transport',
        'subcategories': <String>[],
      },
      {
        'name': 'Installment',
        'subcategories': <String>[],
      },
      {
        'name': 'Savings',
        'subcategories': <String>[],
      },
      {
        'name': 'Personal',
        'subcategories': <String>[],
      },
      {
        'name': 'Other',
        'subcategories': <String>[],
      },
    ];

    final batch = firestore.batch();
    final categoriesRef = firestore.collection('shops').doc(shopId).collection('expenseCategories');

    for (final category in defaultCategories) {
      final categoryDocRef = categoriesRef.doc();
      batch.set(categoryDocRef, {
        'name': category['name'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add subcategories
      final subcategories = category['subcategories'] as List<String>;
      for (final subName in subcategories) {
        final subDocRef = categoryDocRef.collection('subcategories').doc();
        batch.set(subDocRef, {
          'name': subName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  /// Get all staff members of a shop
  Future<List<UserModel>> getShopStaff(String shopId) async {
    final querySnapshot = await firestore
        .collection('users')
        .where('shopId', isEqualTo: shopId)
        .where('role', isEqualTo: 'staff')
        .get();

    return querySnapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  /// Toggle staff active status
  Future<void> toggleStaffStatus(String staffUid, bool active) async {
    await firestore.collection('users').doc(staffUid).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
