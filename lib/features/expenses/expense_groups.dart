import '../../data/models/models.dart';

const noSubcategoryLabel = 'সাব-ক্যাটাগরি ছাড়া';

class ExpenseGroup {
  final String key;
  final String name;
  double total = 0;
  final List<ExpenseModel> items = [];

  ExpenseGroup(this.key, this.name);

  void add(ExpenseModel expense) {
    total += expense.amount;
    items.add(expense);
  }
}

class CategoryGroup extends ExpenseGroup {
  /// Keyed by subcategory; '' holds expenses without a subcategory.
  final Map<String, ExpenseGroup> subs = {};

  CategoryGroup(super.key, super.name);

  bool get hasSubcategories => subs.keys.any((k) => k.isNotEmpty);

  List<ExpenseGroup> get sortedSubs =>
      subs.values.toList()..sort((a, b) => b.total.compareTo(a.total));
}

/// Groups expenses by category, then subcategory; largest category first.
List<CategoryGroup> groupExpenses(Iterable<ExpenseModel> expenses) {
  final groups = <String, CategoryGroup>{};
  for (final e in expenses) {
    final key = e.categoryId.isEmpty ? e.categoryName : e.categoryId;
    final group = groups.putIfAbsent(key, () => CategoryGroup(key, e.categoryName))..add(e);
    final subName = e.subCategoryName?.trim() ?? '';
    final subKey = subName.isEmpty ? '' : (e.subCategoryId ?? subName);
    group.subs
        .putIfAbsent(subKey, () => ExpenseGroup(subKey, subKey.isEmpty ? noSubcategoryLabel : subName))
        .add(e);
  }
  return groups.values.toList()..sort((a, b) => b.total.compareTo(a.total));
}
