import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/localization/strings.dart';
import '../../../data/models/models.dart';
import '../../../widgets/entry_form.dart';
import '../../../widgets/modern_widgets.dart';

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
    final savingsIds = ref.watch(savingsCategoryIdsProvider);
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
                  ScreenHeader(
                    title: tr(locale, 'expenses_title'),
                    actions: [
                      DateChip(
                        label: _formatDate(selectedDate),
                        onTap: () => _selectDate(context, ref),
                        color: AppTheme.errorColor,
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.05),
                  const SizedBox(height: 16),

                  // Totals banner; savings are shown apart from spending
                  if (expensesAsync.valueOrNull case final expenses?) ...[
                    TotalBanner(
                      label: tr(locale, 'total_expenses'),
                      value: CurrencyFormatter.formatNoDecimal(expenses
                          .where((e) => !savingsIds.contains(e.categoryId))
                          .fold<double>(0, (s, e) => s + e.amount)),
                      icon: Icons.receipt_long_rounded,
                      gradient: AppTheme.errorGradient,
                      trailingLabel: tr(locale, 'cash_expenses'),
                      trailingValue: CurrencyFormatter.formatNoDecimal(expenses
                          .where((e) => e.isCash && !savingsIds.contains(e.categoryId))
                          .fold<double>(0, (s, e) => s + e.amount)),
                    ).animate().fadeIn(delay: 100.ms),
                    if (expenses.any((e) => savingsIds.contains(e.categoryId)))
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: StatusPill(
                          label: tr(locale, 'savings_total', params: {
                            'amount': CurrencyFormatter.formatNoDecimal(expenses
                                .where((e) => savingsIds.contains(e.categoryId))
                                .fold<double>(0, (s, e) => s + e.amount)),
                          }),
                          color: AppTheme.successColor,
                        ),
                      ),
                  ],
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = filteredExpenses[index];
                      return _ExpenseCard(
                            expense: expense,
                            isSavings: savingsIds.contains(expense.categoryId),
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
    showEntryForm(context, ExpenseFormSheet(expense: expense));
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
        try {
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
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tr(locale, 'error_with_message', params: {'message': '$e'}),
                ),
              ),
            );
          }
        }
      }
    }
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
  final bool isSavings;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.isSavings,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      if (expense.subCategoryName != null) expense.subCategoryName!,
      if (expense.note != null && expense.note!.isNotEmpty) expense.note!,
    ].join(' · ');

    return EntryCard(
      icon: isSavings ? Icons.savings_rounded : Icons.receipt_long_rounded,
      color: isSavings ? AppTheme.successColor : AppTheme.errorColor,
      title: expense.categoryName,
      subtitle: Row(
        children: [
          StatusPill(
            label: expense.isCash ? 'ক্যাশ থেকে' : 'ক্যাশের বাইরে',
            color: isSavings
                ? AppTheme.successColor
                : expense.isCash ? AppTheme.errorColor : AppTheme.infoColor,
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                details,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      amount: CurrencyFormatter.formatNoDecimal(expense.amount),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class ExpenseFormSheet extends ConsumerStatefulWidget {
  final ExpenseModel? expense;

  const ExpenseFormSheet({super.key, this.expense});

  @override
  ConsumerState<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<ExpenseFormSheet> {
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
      if (mounted) setState(() => _isLoading = false);
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
              const SheetHandle(),
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
                    child: PaymentTypeButton(
                      label: 'ক্যাশ থেকে',
                      icon: Icons.point_of_sale_rounded,
                      isSelected: _paymentType == PaymentType.cash,
                      color: AppTheme.errorColor,
                      onTap: () =>
                          setState(() => _paymentType = PaymentType.cash),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PaymentTypeButton(
                      label: 'ক্যাশের বাইরে',
                      icon: Icons.account_balance_wallet_outlined,
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