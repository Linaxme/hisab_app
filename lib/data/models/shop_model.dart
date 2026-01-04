import 'package:cloud_firestore/cloud_firestore.dart';

/// Shop model
class ShopModel {
  final String id;
  final String name;
  final String inviteCode;
  final String ownerUid;
  final bool showProfit;
  final DateTime createdAt;

  ShopModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerUid,
    this.showProfit = true,
    required this.createdAt,
  });

  factory ShopModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopModel(
      id: doc.id,
      name: data['name'] ?? '',
      inviteCode: data['inviteCode'] ?? '',
      ownerUid: data['ownerUid'] ?? '',
      showProfit: data['showProfit'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'inviteCode': inviteCode,
      'ownerUid': ownerUid,
      'showProfit': showProfit,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  ShopModel copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? ownerUid,
    bool? showProfit,
    DateTime? createdAt,
  }) {
    return ShopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      ownerUid: ownerUid ?? this.ownerUid,
      showProfit: showProfit ?? this.showProfit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
