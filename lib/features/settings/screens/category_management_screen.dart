import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('খরচের ক্যাটাগরি'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'কোনো ক্যাটাগরি নেই',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCategoryForm(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('ক্যাটাগরি যোগ করুন'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryCard(category: category);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          print('Categories loading error: $error');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('ক্যাটাগরি লোড করতে সমস্যা হয়েছে'),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryForm(context, ref),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('ক্যাটাগরি যোগ', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showCategoryForm(BuildContext context, WidgetRef ref, [ExpenseCategoryModel? category]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CategoryFormSheet(category: category),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final ExpenseCategoryModel category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subcategoriesAsync = ref.watch(expenseSubcategoriesProvider(category.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.category, color: AppTheme.primaryColor),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showCategoryForm(context, ref, category),
            ),
            IconButton(
              icon: Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
              onPressed: () => _deleteCategory(context, ref),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          subcategoriesAsync.when(
            data: (subcategories) {
              return Column(
                children: [
                  ...subcategories.map((sub) => _SubcategoryTile(
                    subcategory: sub,
                    categoryId: category.id,
                  )),
                  ListTile(
                    leading: const Icon(Icons.add, color: AppTheme.primaryColor),
                    title: const Text('সাব-ক্যাটাগরি যোগ করুন'),
                    onTap: () => _showSubcategoryForm(context, ref, category.id),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) {
              print('Subcategories loading error for category ${category.id}: $error');
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('সাব-ক্যাটাগরি লোড করতে সমস্যা'),
                    const SizedBox(height: 4),
                    Text(
                      error.toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCategoryForm(BuildContext context, WidgetRef ref, ExpenseCategoryModel category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CategoryFormSheet(category: category),
    );
  }

  void _showSubcategoryForm(BuildContext context, WidgetRef ref, String categoryId, [ExpenseSubCategoryModel? subcategory]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SubcategoryFormSheet(
        categoryId: categoryId,
        subcategory: subcategory,
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ক্যাটাগরি ডিলিট করুন?'),
        content: Text('${category.name} এবং এর সব সাব-ক্যাটাগরি ডিলিট হয়ে যাবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('ডিলিট', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repository = ref.read(expensesRepositoryProvider);
      if (repository != null) {
        await repository.deleteCategory(category.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ক্যাটাগরি ডিলিট হয়েছে')),
          );
        }
      }
    }
  }
}

class _SubcategoryTile extends ConsumerWidget {
  final ExpenseSubCategoryModel subcategory;
  final String categoryId;

  const _SubcategoryTile({
    required this.subcategory,
    required this.categoryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Text(subcategory.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _showSubcategoryForm(context, ref),
          ),
          IconButton(
            icon: Icon(Icons.delete, size: 18, color: AppTheme.errorColor),
            onPressed: () => _deleteSubcategory(context, ref),
          ),
        ],
      ),
    );
  }

  void _showSubcategoryForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SubcategoryFormSheet(
        categoryId: categoryId,
        subcategory: subcategory,
      ),
    );
  }

  Future<void> _deleteSubcategory(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('সাব-ক্যাটাগরি ডিলিট করুন?'),
        content: Text('${subcategory.name} ডিলিট হয়ে যাবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('ডিলিট', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repository = ref.read(expensesRepositoryProvider);
      if (repository != null) {
        await repository.deleteSubcategory(categoryId, subcategory.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('সাব-ক্যাটাগরি ডিলিট হয়েছে')),
          );
        }
      }
    }
  }
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  final ExpenseCategoryModel? category;

  const _CategoryFormSheet({this.category});

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _isEditing ? 'ক্যাটাগরি এডিট' : 'নতুন ক্যাটাগরি',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'ক্যাটাগরির নাম',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'ক্যাটাগরির নাম দিন';
                }
                return null;
              },
              autofocus: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEditing ? 'আপডেট করুন' : 'যোগ করুন',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(expensesRepositoryProvider);
      if (repository == null) throw Exception('Repository not available');

      final currentUser = ref.read(currentUserProvider).value;

      if (_isEditing) {
        await repository.updateCategory(
          widget.category!.id,
          _nameController.text.trim(),
        );
      } else {
        await repository.addCategory(
          _nameController.text.trim(),
          currentUser?.uid ?? '',
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'ক্যাটাগরি আপডেট হয়েছে' : 'ক্যাটাগরি যোগ হয়েছে'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('সমস্যা হয়েছে: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _SubcategoryFormSheet extends ConsumerStatefulWidget {
  final String categoryId;
  final ExpenseSubCategoryModel? subcategory;

  const _SubcategoryFormSheet({
    required this.categoryId,
    this.subcategory,
  });

  @override
  ConsumerState<_SubcategoryFormSheet> createState() => _SubcategoryFormSheetState();
}

class _SubcategoryFormSheetState extends ConsumerState<_SubcategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;

  bool get _isEditing => widget.subcategory != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subcategory?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _isEditing ? 'সাব-ক্যাটাগরি এডিট' : 'নতুন সাব-ক্যাটাগরি',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'সাব-ক্যাটাগরির নাম',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'সাব-ক্যাটাগরির নাম দিন';
                }
                return null;
              },
              autofocus: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEditing ? 'আপডেট করুন' : 'যোগ করুন',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(expensesRepositoryProvider);
      if (repository == null) throw Exception('Repository not available');

      final currentUser = ref.read(currentUserProvider).value;

      if (_isEditing) {
        await repository.updateSubcategory(
          widget.categoryId,
          widget.subcategory!.id,
          _nameController.text.trim(),
        );
      } else {
        await repository.addSubcategory(
          widget.categoryId,
          _nameController.text.trim(),
          currentUser?.uid ?? '',
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'সাব-ক্যাটাগরি আপডেট হয়েছে' : 'সাব-ক্যাটাগরি যোগ হয়েছে'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('সমস্যা হয়েছে: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
