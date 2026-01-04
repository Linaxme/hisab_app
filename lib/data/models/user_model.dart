import 'package:cloud_firestore/cloud_firestore.dart';

/// User model for authentication and profile
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'owner' or 'staff'
  final String? shopId;
  final bool active;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.shopId,
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
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
