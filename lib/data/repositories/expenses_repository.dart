import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';

class ExpensesRepository {
  final FirebaseFirestore _firestore;
  final String shopId;

  ExpensesRepository({
    required this.shopId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _expensesCollection =>
      _firestore.collection('shops').doc(shopId).collection('expenses');

  CollectionReference<Map<String, dynamic>> get _categoriesCollection =>
      _firestore.collection('shops').doc(shopId).collection('expenseCategories');

  // ============ EXPENSES ============

  // Create
  Future<String> addExpense(ExpenseModel expense) async {
    final docRef = await _expensesCollection.add(expense.toFirestore());
    return docRef.id;
  }

  // Read - Stream for real-time updates
  Stream<List<ExpenseModel>> watchExpensesByDate(String date) {
    return _expensesCollection
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
          final expenses = snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();
          expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return expenses;
        });
  }

  // Read - Single fetch
  Future<List<ExpenseModel>> getExpensesByDate(String date) async {
    final snapshot = await _expensesCollection
        .where('date', isEqualTo: date)
        .get();
    final expenses = snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();
    expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return expenses;
  }

  // Read - Date range for reports
  Future<List<ExpenseModel>> getExpensesByDateRange(String startDate, String endDate) async {
    final snapshot = await _expensesCollection
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
    final expenses = snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  // Update
  Future<void> updateExpense(ExpenseModel expense) async {
    await _expensesCollection.doc(expense.id).update(expense.toUpdateFirestore());
  }

  // Delete
  Future<void> deleteExpense(String expenseId) async {
    await _expensesCollection.doc(expenseId).delete();
  }

  // Get totals for a date
  Future<Map<String, double>> getDayTotals(String date) async {
    final expenses = await getExpensesByDate(date);
    
    double totalExpenses = 0;
    double cashExpenses = 0;
    double nonCashExpenses = 0;

    for (final expense in expenses) {
      totalExpenses += expense.amount;
      if (expense.isCash) {
        cashExpenses += expense.amount;
      } else {
        nonCashExpenses += expense.amount;
      }
    }

    return {
      'totalExpenses': totalExpenses,
      'cashExpenses': cashExpenses,
      'nonCashExpenses': nonCashExpenses,
    };
  }

  // ============ CATEGORIES ============

  // Create default categories for new shop
  Future<void> createDefaultCategories() async {
    final defaultCategories = [
      {'name': 'দোকান খরচ', 'order': 1, 'subcategories': ['নাস্তা', 'ব্যাগ', 'ভাড়া', 'বিদ্যুৎ', 'জেনারেটর', 'অন্যান্য বিল', 'স্টাফ বিল']},
      {'name': 'বাড়ির খরচ', 'order': 2, 'subcategories': []},
      {'name': 'মাল কেনা', 'order': 3, 'subcategories': []},
      {'name': 'যাতায়াত', 'order': 4, 'subcategories': []},
      {'name': 'কিস্তি', 'order': 5, 'subcategories': []},
      {'name': 'সঞ্চয়', 'order': 6, 'subcategories': [], 'isSavings': true},
      {'name': 'ব্যক্তিগত', 'order': 7, 'subcategories': []},
      {'name': 'অন্যান্য', 'order': 8, 'subcategories': []},
    ];

    final batch = _firestore.batch();
    
    for (final category in defaultCategories) {
      final catDoc = _categoriesCollection.doc();
      batch.set(catDoc, {
        'name': category['name'],
        'order': category['order'],
        'createdAt': FieldValue.serverTimestamp(),
        if (category['isSavings'] == true) 'isSavings': true,
      });

      final subcategories = category['subcategories'] as List<String>;
      for (int i = 0; i < subcategories.length; i++) {
        final subDoc = catDoc.collection('subcategories').doc();
        batch.set(subDoc, {
          'name': subcategories[i],
          'order': i + 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  // Get all categories
  Stream<List<ExpenseCategoryModel>> watchCategories() {
    return _categoriesCollection
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs.map((doc) => ExpenseCategoryModel.fromFirestore(doc)).toList();
          // Sort client-side to avoid index requirement
          categories.sort((a, b) => a.order.compareTo(b.order));
          return categories;
        });
  }

  Future<List<ExpenseCategoryModel>> getCategories() async {
    final snapshot = await _categoriesCollection.get();
    final categories = snapshot.docs.map((doc) => ExpenseCategoryModel.fromFirestore(doc)).toList();
    categories.sort((a, b) => a.order.compareTo(b.order));
    return categories;
  }

  // Add category
  Future<String> addCategory(String name, String createdBy) async {
    // Get the highest order number
    final snapshot = await _categoriesCollection.get();
    final categories = snapshot.docs.map((doc) => doc.data()['order'] as int? ?? 0).toList();
    final nextOrder = categories.isEmpty ? 1 : (categories.reduce((a, b) => a > b ? a : b)) + 1;
    
    final docRef = await _categoriesCollection.add({
      'name': name,
      'order': nextOrder,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Update category
  Future<void> updateCategory(String categoryId, String name) async {
    await _categoriesCollection.doc(categoryId).update({'name': name});
  }

  Future<void> setCategorySavings(String categoryId, bool isSavings) async {
    await _categoriesCollection.doc(categoryId).update({'isSavings': isSavings});
  }

  // Delete category
  Future<void> deleteCategory(String categoryId) async {
    // Delete subcategories first
    final subSnapshot = await _categoriesCollection
        .doc(categoryId)
        .collection('subcategories')
        .get();
    
    for (final doc in subSnapshot.docs) {
      await doc.reference.delete();
    }
    
    await _categoriesCollection.doc(categoryId).delete();
  }

  // Get subcategories
  Stream<List<ExpenseSubCategoryModel>> watchSubcategories(String categoryId) {
    return _categoriesCollection
        .doc(categoryId)
        .collection('subcategories')
        .snapshots()
        .map((snapshot) {
          final subcategories = snapshot.docs.map((doc) => ExpenseSubCategoryModel.fromFirestore(doc)).toList();
          // Sort client-side to avoid index requirement
          subcategories.sort((a, b) => a.order.compareTo(b.order));
          return subcategories;
        });
  }

  Future<List<ExpenseSubCategoryModel>> getSubcategories(String categoryId) async {
    final snapshot = await _categoriesCollection
        .doc(categoryId)
        .collection('subcategories')
        .get();
    final subcategories = snapshot.docs.map((doc) => ExpenseSubCategoryModel.fromFirestore(doc)).toList();
    subcategories.sort((a, b) => a.order.compareTo(b.order));
    return subcategories;
  }

  // Add subcategory
  Future<String> addSubcategory(String categoryId, String name, String createdBy) async {
    // Get the highest order number
    final snapshot = await _categoriesCollection
        .doc(categoryId)
        .collection('subcategories')
        .get();
    final orders = snapshot.docs.map((doc) => doc.data()['order'] as int? ?? 0).toList();
    final nextOrder = orders.isEmpty ? 1 : (orders.reduce((a, b) => a > b ? a : b)) + 1;
    
    final docRef = await _categoriesCollection
        .doc(categoryId)
        .collection('subcategories')
        .add({
      'name': name,
      'order': nextOrder,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Update subcategory
  Future<void> updateSubcategory(String categoryId, String subId, String name) async {
    await _categoriesCollection
        .doc(categoryId)
        .collection('subcategories')
        .doc(subId)
        .update({'name': name});
  }

  // Delete subcategory
  Future<void> deleteSubcategory(String categoryId, String subId) async {
    await _categoriesCollection
        .doc(categoryId)
        .collection('subcategories')
        .doc(subId)
        .delete();
  }
}
