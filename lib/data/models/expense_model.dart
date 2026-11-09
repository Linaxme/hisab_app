import 'package:cloud_firestore/cloud_firestore.dart';
import 'sale_model.dart';

class ExpenseModel {
  final String id;
  final double amount;
  final String categoryId;
  final String categoryName;
  final String? subCategoryId;
  final String? subCategoryName;
  final String? note;
  final PaymentType paymentType;
  final String date; // YYYY-MM-DD
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    this.subCategoryId,
    this.subCategoryName,
    this.note,
    required this.paymentType,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      amount: (data['amount'] ?? 0).toDouble(),
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      subCategoryId: data['subCategoryId'],
      subCategoryName: data['subCategoryName'],
      note: data['note'],
      paymentType: data['paymentType'] == 'noncash' 
          ? PaymentType.noncash 
          : PaymentType.cash,
      date: data['date'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'subCategoryId': subCategoryId,
      'subCategoryName': subCategoryName,
      'note': note,
      'paymentType': paymentType == PaymentType.cash ? 'cash' : 'noncash',
      'date': date,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': null,
    };
  }

  Map<String, dynamic> toUpdateFirestore() {
    return {
      'amount': amount,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'subCategoryId': subCategoryId,
      'subCategoryName': subCategoryName,
      'note': note,
      'paymentType': paymentType == PaymentType.cash ? 'cash' : 'noncash',
      'date': date,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ExpenseModel copyWith({
    String? id,
    double? amount,
    String? categoryId,
    String? categoryName,
    String? subCategoryId,
    String? subCategoryName,
    String? note,
    PaymentType? paymentType,
    String? date,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      subCategoryName: subCategoryName ?? this.subCategoryName,
      note: note ?? this.note,
      paymentType: paymentType ?? this.paymentType,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isCash => paymentType == PaymentType.cash;
}

class ExpenseCategoryModel {
  final String id;
  final String name;
  final int order;
  final DateTime createdAt;

  /// Money put aside (e.g. a savings group), kept out of expense totals.
  final bool isSavings;

  ExpenseCategoryModel({
    required this.id,
    required this.name,
    required this.order,
    required this.createdAt,
    this.isSavings = false,
  });

  factory ExpenseCategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseCategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSavings: data['isSavings'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
      if (isSavings) 'isSavings': true,
    };
  }
}

class ExpenseSubCategoryModel {
  final String id;
  final String name;
  final int order;
  final DateTime createdAt;

  ExpenseSubCategoryModel({
    required this.id,
    required this.name,
    required this.order,
    required this.createdAt,
  });

  factory ExpenseSubCategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseSubCategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
