import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/localization/strings.dart';
import '../../../data/models/models.dart';
import '../../../core/utils/responsive.dart';
import '../../../widgets/entry_form.dart';
import '../../../widgets/modern_widgets.dart';

class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key});

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen> {
  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _pickDate() async {
    final selectedDate = ref.read(selectedDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.errorColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).scaffoldBackgroundColor,
              onSurface: Theme.of(context).textTheme.bodyLarge!.color!,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final returnsAsync = ref.watch(returnsByDateProvider);
    final totalAsync = ref.watch(returnsTotalProvider);
    final dateStr = formatDateForQuery(selectedDate);
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
                    title: tr(locale, 'returns_title'),
                    onBack: context.isWide ? null : () => _handleBack(context),
                    actions: [
                      DateChip(
                        label: dateStr,
                        onTap: _pickDate,
                        color: AppTheme.violetColor,
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.05),
                  const SizedBox(height: 16),
                  // Total banner
                  totalAsync
                      .when(
                        data: (total) => TotalBanner(
                          label: tr(locale, 'total_returns'),
                          value: CurrencyFormatter.formatNoDecimal(total),
                          icon: Icons.assignment_return_rounded,
                          gradient: AppTheme.purpleGradient,
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      )
                      .animate()
                      .fadeIn(delay: 100.ms),
                ],
              ),
            ),

            // Returns List
            Expanded(
              child: returnsAsync.when(
                data: (returns) {
                  if (returns.isEmpty) {
                    return _EmptyState(locale: locale);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: returns.length,
                    itemBuilder: (context, index) {
                      final returnItem = returns[index];
                      return _ReturnCard(
                            returnItem: returnItem,
                            locale: locale,
                            onEdit: () => _showReturnForm(
                              context,
                              returnItem: returnItem,
                            ),
                            onDelete: () => _deleteReturn(returnItem),
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

  void _showReturnForm(BuildContext context, {ReturnModel? returnItem}) {
    showEntryForm(context, ReturnFormSheet(returnItem: returnItem));
  }

  Future<void> _deleteReturn(ReturnModel returnItem) async {
    final locale = ref.read(languageProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr(locale, 'delete_return_title')),
        content: Text(tr(locale, 'delete_return_confirm')),
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
      final repository = ref.read(returnsRepositoryProvider);
      if (repository != null) {
        try {
          await repository.deleteReturn(returnItem.id);

          // Refresh providers to update UI
          ref.invalidate(returnsByDateProvider);
          ref.invalidate(returnsTotalProvider);
          ref.invalidate(liveCashProvider);

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(tr(locale, 'return_deleted'))));
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_return_rounded,
              size: 64,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr(locale, 'no_returns_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            tr(locale, 'no_returns_sub'),
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  final ReturnModel returnItem;
  final Locale locale;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReturnCard({
    required this.returnItem,
    required this.locale,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return EntryCard(
      icon: Icons.assignment_return_rounded,
      color: AppTheme.violetColor,
      title: returnItem.note ?? tr(locale, 'return_default_note'),
      subtitle: Text(
        returnItem.date,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      amount: CurrencyFormatter.formatNoDecimal(returnItem.amount),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class ReturnFormSheet extends ConsumerStatefulWidget {
  final ReturnModel? returnItem;

  const ReturnFormSheet({super.key, this.returnItem});

  @override
  ConsumerState<ReturnFormSheet> createState() => _ReturnFormSheetState();
}

class _ReturnFormSheetState extends ConsumerState<ReturnFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.returnItem != null) {
      _amountController.text = widget.returnItem!.amount.toStringAsFixed(0);
      _noteController.text = widget.returnItem!.note ?? '';
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

    setState(() => _isLoading = true);
    final locale = ref.read(languageProvider);

    try {
      final repository = ref.read(returnsRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;
      final selectedDate = ref.read(selectedDateProvider);

      if (repository == null || currentUser == null) {
        throw Exception('Repository or user not available');
      }

      final dateStr = formatDateForQuery(selectedDate);
      final returnModel = ReturnModel(
        id: widget.returnItem?.id ?? '',
        amount: double.parse(_amountController.text),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        date: widget.returnItem?.date ?? dateStr,
        createdBy: currentUser.uid,
        createdAt: widget.returnItem?.createdAt ?? DateTime.now(),
      );

      if (widget.returnItem == null) {
        await repository.addReturn(returnModel);
      } else {
        await repository.updateReturn(returnModel);
      }

      // Refresh providers to update UI
      ref.invalidate(returnsByDateProvider);
      ref.invalidate(returnsTotalProvider);
      ref.invalidate(liveCashProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.returnItem == null
                  ? tr(locale, 'return_added')
                  : tr(locale, 'return_updated'),
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
        padding: const EdgeInsets.all(24),
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
                widget.returnItem == null
                    ? tr(locale, 'new_return')
                    : tr(locale, 'edit_return'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: tr(locale, 'return_amount'),
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

              // Note
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: tr(locale, 'reason_note_optional'),
                  prefixIcon: const Icon(Icons.note_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
                            widget.returnItem == null
                                ? tr(locale, 'add')
                                : tr(locale, 'update'),
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
