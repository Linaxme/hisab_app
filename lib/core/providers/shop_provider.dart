import 'dart:math';
import 'package:flutter/foundation.dart';
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

/// The shop's staff accounts, loaded only for the owner.
final shopStaffProvider = StreamProvider<List<UserModel>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final shop = ref.watch(currentShopProvider).valueOrNull;
  if (user == null || !user.isOwner || shop == null || shop.ownerUid != user.uid) {
    return Stream.value(const []);
  }
  return ref.watch(authRepositoryProvider).watchStaffByShopId(shop.id);
});

/// Keeps the shop's member list, name labels and invite code registration up to date.
/// Older shops get their `members` filled in the first time they open this version.
final shopDataSyncProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final shop = ref.watch(currentShopProvider).valueOrNull;
  if (user == null || !user.active || shop == null || user.shopId != shop.id) return;
  final staff = ref.watch(shopStaffProvider);
  if (staff.isLoading && !staff.hasValue) return;
  await ref.read(shopRepositoryProvider).syncShopData(
        user: user,
        shop: shop,
        staff: staff.valueOrNull ?? const [],
      );
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

  /// Invite code lookup entry; the names are labels so the database shows whose code it is.
  Map<String, dynamic> _codeData(String shopId, String shopName, String ownerName) => {
        'shopId': shopId,
        'shopName': shopName,
        'ownerName': ownerName,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Member list and labels are copies; failures are left for [syncShopData] to repair.
  Future<void> _quietly(Future<void> Function() write) async {
    try {
      await write();
    } on FirebaseException catch (e) {
      debugPrint('Shop data sync skipped: ${e.code} ${e.message}');
    }
  }

  /// Create a new shop (Owner only)
  Future<String> createShop({
    required String name,
    required String ownerUid,
  }) async {
    final inviteCode = await _generateUnusedInviteCode();
    final owner = await authRepository.getUserById(ownerUid);
    final ownerName = owner?.name ?? '';
    
    final shop = ShopModel(
      id: '',
      name: name,
      inviteCode: inviteCode,
      ownerUid: ownerUid,
      ownerName: ownerName,
      createdAt: DateTime.now(),
    );

    final docRef = await firestore.collection('shops').add(shop.toFirestore());
    
    // Update user with shopId
    await authRepository.updateUserShopId(ownerUid, docRef.id);

    await _inviteCodes.doc(inviteCode).set(_codeData(docRef.id, name, ownerName));

    if (owner != null) {
      await _quietly(() => authRepository.upsertMember(docRef.id, owner, isNew: true));
    }
    
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

    final staff = await authRepository.getUserById(userId);
    if (staff != null) {
      await _quietly(() => authRepository.upsertMember(shopId, staff, isNew: true));
    }
    
    return shopId;
  }

  /// Regenerate invite code (Owner only)
  Future<String> regenerateInviteCode(String shopId) async {
    final shop = await getShopById(shopId);
    final newCode = await _generateUnusedInviteCode();

    await _inviteCodes.doc(newCode).set(_codeData(shopId, shop?.name ?? '', shop?.ownerName ?? ''));
    
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
  Future<void> ensureInviteCodeRegistered(ShopModel shop, {String? ownerName}) async {
    if (shop.inviteCode.isEmpty) {
      await regenerateInviteCode(shop.id);
      return;
    }

    final owner = ownerName ?? shop.ownerName;
    final codeDoc = await _inviteCodes.doc(shop.inviteCode).get();
    final data = codeDoc.data();
    if (!codeDoc.exists) {
      await _inviteCodes.doc(shop.inviteCode).set(_codeData(shop.id, shop.name, owner));
    } else if (data?['shopId'] != shop.id) {
      await regenerateInviteCode(shop.id);
    } else if (data?['shopName'] != shop.name || data?['ownerName'] != owner) {
      await _quietly(() => codeDoc.reference.update({'shopName': shop.name, 'ownerName': owner}));
    }
  }

  /// Fills in and refreshes the shop's member list and name labels, writing only
  /// what is missing or out of date. The owner also covers staff who never open the app.
  Future<void> syncShopData({
    required UserModel user,
    required ShopModel shop,
    List<UserModel> staff = const [],
  }) async {
    final isShopOwner = user.isOwner && shop.ownerUid == user.uid;
    final users = firestore.collection('users');

    if (isShopOwner) {
      await _quietly(() => ensureInviteCodeRegistered(shop, ownerName: user.name));
      if (shop.ownerName != user.name) {
        await _quietly(() => firestore.collection('shops').doc(shop.id).update({'ownerName': user.name}));
      }
    }
    if (user.shopName != shop.name) {
      await _quietly(() => users.doc(user.uid).update({'shopName': shop.name}));
    }

    await _quietly(() async {
      final people = [user, if (isShopOwner) ...staff.where((s) => s.shopId == shop.id)];
      final Map<String, MemberModel> existing;
      if (isShopOwner) {
        final snapshot = await firestore.collection('shops').doc(shop.id).collection('members').get();
        existing = {for (final doc in snapshot.docs) doc.id: MemberModel.fromFirestore(doc)};
      } else {
        final doc = await authRepository.memberRef(shop.id, user.uid).get();
        existing = {if (doc.exists) doc.id: MemberModel.fromFirestore(doc)};
      }

      final stale = people.where((p) => !(existing[p.uid]?.matches(p) ?? false)).toList();
      for (final person in stale) {
        await authRepository.upsertMember(shop.id, person, isNew: !existing.containsKey(person.uid));
      }
    });

    if (isShopOwner) {
      for (final s in staff.where((s) => s.shopId == shop.id && s.shopName != shop.name)) {
        await _quietly(() => users.doc(s.uid).update({'shopName': shop.name}));
      }
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
    final shop = await getShopById(shopId);
    if (shop != null && shop.inviteCode.isNotEmpty) {
      await _quietly(() => _inviteCodes.doc(shop.inviteCode).update({'shopName': name}));
    }
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
