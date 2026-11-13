import 'package:cloud_firestore/cloud_firestore.dart';

/// User model for authentication and profile
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'owner' or 'staff'
  final String? shopId;
  /// Label only, so the database shows which shop the user belongs to
  final String? shopName;
  final bool active;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.shopId,
    this.shopName,
    this.active = true,
    required this.createdAt,
  });

  bool get isOwner => role == 'owner';
  bool get isStaff => role == 'staff';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'staff',
      shopId: data['shopId'],
      shopName: data['shopName'],
      active: data['active'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'shopId': shopId,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? shopId,
    bool? active,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      shopName: shopName,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A shop's owner or staff member (`shops/{shopId}/members/{uid}`).
/// A copy of the `users` document kept inside the shop; `users` stays the source of truth.
class MemberModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool active;
  final DateTime? joinedAt;

  const MemberModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.active = true,
    this.joinedAt,
  });

  bool get isOwner => role == 'owner';

  factory MemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return MemberModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'staff',
      active: data['active'] ?? true,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Fields copied from the user's own document.
  static Map<String, dynamic> fieldsOf(UserModel user) => {
        'uid': user.uid,
        'name': user.name,
        'email': user.email,
        'role': user.role,
        'active': user.active,
      };

  bool matches(UserModel user) =>
      name == user.name && email == user.email && role == user.role && active == user.active;
}
