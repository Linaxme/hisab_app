import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/localization/strings.dart';
import '../../../data/models/models.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesByDateProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final totals = ref.watch(expensesTotalsProvider);
    final locale = ref.watch(languageProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr(locale, 'expenses_title'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      // Date Picker
                      InkWell(
                        onTap: () => _selectDate(context, ref),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: AppTheme.errorColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(selectedDate),
                                style: const TextStyle(
                                  color: AppTheme.errorColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 16),

                  // Totals Row
                  totals.when(
                    data: (data) => Row(
                      children: [
                        Expanded(
                          child: _TotalCard(
                            label: tr(locale, 'total_expenses'),
                            value: CurrencyFormatter.formatNoDecimal(
                              data['totalExpenses'] ?? 0,
                            ),
                            gradient: AppTheme.errorGradient,
                            amountColor: AppTheme.errorColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TotalCard(
                            label: tr(locale, 'cash_expenses'),
                            value: CurrencyFormatter.formatNoDecimal(
                              data['cashExpenses'] ?? 0,
                            ),
                            gradient: AppTheme.warningGradient,
                            amountColor: AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // Expenses List
            Expanded(
              child: expensesAsync.when(
                data: (expenses) {
                  // Filter expenses based on search query
                  final filteredExpenses = _searchQuery.isEmpty
                      ? expenses
                      : expenses.where((expense) {
                          final note = (expense.note ?? '').toLowerCase();
                          final categoryName = expense.categoryName
                              .toLowerCase();
                          return note.contains(_searchQuery) ||
                              categoryName.contains(_searchQuery);
                        }).toList();

                  if (filteredExpenses.isEmpty) {
                    return _searchQuery.isNotEmpty
                        ? _EmptySearchState(query: _searchQuery, locale: locale)
                        : _EmptyState(locale: locale);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = filteredExpenses[index];
                      return _ExpenseCard(
                            expense: expense,
                            onEdit: () =>
                                _showExpenseForm(context, expense: expense),
                            onDelete: () => _deleteExpense(expense),
                          )
                          .animate()
                          .fadeIn(delay: (100 * index).ms)
                          .slideX(begin: 0.1);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(tr(locale, 'load_error'))),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseForm(context),
        backgroundColor: AppTheme.errorColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          tr(locale, 'add_expense_btn'),
          style: const TextStyle(color: Colors.white),
        ),
      ).animate().slideY(begin: 1, delay: 300.ms).fadeIn(),
    );
  }

  Future<void> _selectDate(BuildContext context, WidgetRef ref) async {
    final selectedDate = ref.read(selectedDateProvider);
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date != null) {
      ref.read(selectedDateProvider.notifier).state = date;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'আজ';
    if (dateOnly == yesterday) return 'গতকাল';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showExpenseForm(BuildContext context, {ExpenseModel? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExpenseFormSheet(expense: expense),
    );
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final locale = ref.read(languageProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr(locale, 'delete_expense_title')),
        content: Text(tr(locale, 'delete_expense_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(locale, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(
              tr(locale, 'delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repository = ref.read(expensesRepositoryProvider);
      if (repository != null) {
        await repository.deleteExpense(expense.id);

        // Refresh providers to update UI
        ref.invalidate(expensesByDateProvider);
        ref.invalidate(expensesTotalsProvider);
        ref.invalidate(liveCashProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(locale, 'expense_deleted'))),
          );
        }
      }
    }
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final String value;
  final LinearGradient gradient;
  final Color? amountColor;

  const _TotalCard({
    required this.label,
    required this.value,
    required this.gradient,
    this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: amountColor ?? AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Locale locale;

  const _EmptyState({required this.locale});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_cart_rounded,
              size: 64,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr(locale, 'no_expenses_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            tr(locale, 'no_expenses_sub'),
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  final String query;
  final Locale locale;

  const _EmptySearchState({required this.query, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr(locale, 'no_results_expenses_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            tr(locale, 'no_results_expenses_sub', params: {'query': query}),
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.blue.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.blue.withValues(alpha: 0.2)
                : Colors.blue.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Category icon - smaller
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.errorColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.categoryName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: expense.isCash
                                  ? AppTheme.errorColor.withValues(alpha: 0.1)
                                  : AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              expense.isCash ? 'নগদ' : 'অ-নগদ',
                              style: TextStyle(
                                fontSize: 9,
                                color: expense.isCash
                                    ? AppTheme.errorColor
                                    : AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (expense.subCategoryName != null) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                expense.subCategoryName!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Amount and actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatNoDecimal(expense.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onEdit,
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: onDelete,
                          child: const Icon(
                            Icons.delete_rounded,
                            size: 16,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseFormSheet extends ConsumerStatefulWidget {
  final ExpenseModel? expense;

  const _ExpenseFormSheet({this.expense});

  @override
  ConsumerState<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  ExpenseCategoryModel? _selectedCategory;
  ExpenseSubCategoryModel? _selectedSubCategory;
  PaymentType _paymentType = PaymentType.cash;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _amountController.text = widget.expense!.amount.toStringAsFixed(0);
      _noteController.text = widget.expense!.note ?? '';
      _paymentType = widget.expense!.paymentType;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      final locale = ref.read(languageProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(locale, 'category_required'))));
      return;
    }

    setState(() => _isLoading = true);
    final locale = ref.read(languageProvider);

    try {
      final repository = ref.read(expensesRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;
      final selectedDate = ref.read(selectedDateProvider);

      if (repository == null || currentUser == null) {
        throw Exception('Repository or user not available');
      }

      final dateStr = formatDateForQuery(selectedDate);
      final expense = ExpenseModel(
        id: widget.expense?.id ?? '',
        amount: double.parse(_amountController.text),
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        subCategoryId: _selectedSubCategory?.id,
        subCategoryName: _selectedSubCategory?.name,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        paymentType: _paymentType,
        date: dateStr,
        createdBy: currentUser.uid,
        createdAt: widget.expense?.createdAt ?? DateTime.now(),
      );

      if (widget.expense == null) {
        await repository.addExpense(expense);
      } else {
        await repository.updateExpense(expense);
      }

      // Refresh providers to update UI
      ref.invalidate(expensesByDateProvider);
      ref.invalidate(expensesTotalsProvider);
      ref.invalidate(liveCashProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense == null
                  ? tr(locale, 'expense_added')
                  : tr(locale, 'expense_updated'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                locale,
                'error_with_message',
                params: {'message': e.toString()},
              ),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final locale = ref.watch(languageProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                widget.expense == null
                    ? tr(locale, 'new_expense')
                    : tr(locale, 'edit_expense'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr(locale, 'amount'),
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  prefixText: '৳ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr(locale, 'amount_required');
                  }
                  if (double.tryParse(value) == null) {
                    return tr(locale, 'amount_invalid');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              categoriesAsync.when(
                data: (categories) {
                  // Pre-select if editing
                  if (widget.expense != null &&
                      _selectedCategory == null &&
                      categories.isNotEmpty) {
                    _selectedCategory = categories
                        .where((c) => c.id == widget.expense!.categoryId)
                        .firstOrNull;
                  }

                  return DropdownButtonFormField<ExpenseCategoryModel>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: tr(locale, 'select_category'),
                      prefixIcon: const Icon(Icons.category_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: categories
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                        _selectedSubCategory = null;
                      });
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) {
                  print('Categories loading error: $error');
                  return Text(
                    '${tr(locale, 'load_error')}: ${error.toString()}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Subcategory Dropdown
              if (_selectedCategory != null)
                Consumer(
                  builder: (context, ref, child) {
                    final subcategoriesAsync = ref.watch(
                      expenseSubcategoriesProvider(_selectedCategory!.id),
                    );

                    return subcategoriesAsync.when(
                      data: (subcategories) {
                        if (subcategories.isEmpty)
                          return const SizedBox.shrink();

                        // Pre-select if editing
                        if (widget.expense != null &&
                            _selectedSubCategory == null) {
                          _selectedSubCategory = subcategories
                              .where(
                                (s) => s.id == widget.expense!.subCategoryId,
                              )
                              .firstOrNull;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child:
                              DropdownButtonFormField<ExpenseSubCategoryModel>(
                                initialValue: _selectedSubCategory,
                                decoration: InputDecoration(
                                  labelText: 'সাব-ক্যাটাগরি',
                                  prefixIcon: const Icon(
                                    Icons.subdirectory_arrow_right_rounded,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: subcategories
                                    .map(
                                      (sub) => DropdownMenuItem(
                                        value: sub,
                                        child: Text(sub.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedSubCategory = value;
                                  });
                                },
                              ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (error, stack) {
                        print('Subcategories loading error: $error');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'সাব-ক্যাটাগরি লোড করতে সমস্যা: ${error.toString()}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

              // Note
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'নোট (ঐচ্ছিক)',
                  prefixIcon: const Icon(Icons.note_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Payment Type
              Text(
                'পেমেন্ট টাইপ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PaymentTypeButton(
                      label: 'নগদ',
                      icon: Icons.money_rounded,
                      isSelected: _paymentType == PaymentType.cash,
                      color: AppTheme.errorColor,
                      onTap: () =>
                          setState(() => _paymentType = PaymentType.cash),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentTypeButton(
                      label: 'অ-নগদ',
                      icon: Icons.credit_card_rounded,
                      isSelected: _paymentType == PaymentType.noncash,
                      color: AppTheme.errorColor,
                      onTap: () =>
                          setState(() => _paymentType = PaymentType.noncash),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.errorGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.expense == null ? 'যোগ করুন' : 'আপডেট করুন',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PaymentTypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.errorGradient : null,
          color: isSelected
              ? null
              : (isDark ? AppTheme.darkCard : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
