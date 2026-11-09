import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/strings.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../../core/utils/responsive.dart';
import '../../../widgets/entry_form.dart';
import '../../../widgets/modern_widgets.dart';

class DepositsScreen extends ConsumerStatefulWidget {
  const DepositsScreen({super.key});

  @override
  ConsumerState<DepositsScreen> createState() => _DepositsScreenState();
}

class _DepositsScreenState extends ConsumerState<DepositsScreen> {
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
              primary: AppTheme.accentColor,
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
    final locale = ref.watch(languageProvider);
    final t = (String key, {Map<String, String> params = const {}}) => tr(locale, key, params: params);
    final selectedDate = ref.watch(selectedDateProvider);
    final depositsAsync = ref.watch(depositsByDateProvider);
    final totalAsync = ref.watch(depositsTotalProvider);
    final dateStr = formatDateForQuery(selectedDate);

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
                    title: t('deposits_title'),
                    onBack: context.isWide ? null : () => _handleBack(context),
                    actions: [
                      DateChip(
                        label: dateStr,
                        onTap: _pickDate,
                        color: AppTheme.accentColor,
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.05),
                  const SizedBox(height: 16),
                  // Total banner
                  totalAsync.when(
                    data: (total) => TotalBanner(
                      label: t('total_deposits'),
                      value: CurrencyFormatter.formatNoDecimal(total),
                      icon: Icons.savings_rounded,
                      gradient: AppTheme.accentGradient,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ).animate().fadeIn(delay: 100.ms),
                ],
              ),
            ),
            
            // Deposits List
            Expanded(
              child: depositsAsync.when(
                data: (deposits) {
                  if (deposits.isEmpty) {
                    return _EmptyState(locale: locale);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: deposits.length,
                    itemBuilder: (context, index) {
                      final deposit = deposits[index];
                      return _DepositCard(
                        deposit: deposit,
                        locale: locale,
                        onEdit: () => _showDepositForm(context, deposit: deposit),
                        onDelete: () => _deleteDeposit(deposit),
                      ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.1);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(t('load_error'))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepositForm(BuildContext context, {DepositModel? deposit}) {
    showEntryForm(context, DepositFormSheet(deposit: deposit));
  }

  Future<void> _deleteDeposit(DepositModel deposit) async {
    final locale = ref.read(languageProvider);
    final t = (String key, {Map<String, String> params = const {}}) => tr(locale, key, params: params);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('delete_deposit_title')),
        content: Text(t('delete_deposit_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text(t('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repository = ref.read(depositsRepositoryProvider);
      if (repository != null) {
        try {
          await repository.deleteDeposit(deposit.id);

          // Refresh providers to update UI
          ref.invalidate(depositsByDateProvider);
          ref.invalidate(depositsTotalProvider);
          ref.invalidate(liveCashProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('deposit_deleted'))),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('error_with_message', params: {'message': '$e'}))),
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
    final t = (String key, {Map<String, String> params = const {}}) => tr(locale, key, params: params);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_rounded,
              size: 64,
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t('no_deposits_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t('no_deposits_sub'),
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _DepositCard extends StatelessWidget {
  final DepositModel deposit;
  final Locale locale;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DepositCard({
    required this.deposit,
    required this.locale,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = (String key, {Map<String, String> params = const {}}) => tr(locale, key, params: params);

    return EntryCard(
      icon: deposit.isAutoCreated ? Icons.phone_android_rounded : Icons.savings_rounded,
      color: AppTheme.accentColor,
      title: deposit.note ?? t('deposit_default_note'),
      subtitle: Row(
        children: [
          Text(deposit.date, style: Theme.of(context).textTheme.bodySmall),
          if (deposit.isAutoCreated) ...[
            const SizedBox(width: 6),
            const StatusPill(label: 'Auto', color: AppTheme.infoColor),
          ],
        ],
      ),
      amount: CurrencyFormatter.formatNoDecimal(deposit.amount),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class DepositFormSheet extends ConsumerStatefulWidget {
  final DepositModel? deposit;

  const DepositFormSheet({super.key, this.deposit});

  @override
  ConsumerState<DepositFormSheet> createState() => _DepositFormSheetState();
}

class _DepositFormSheetState extends ConsumerState<DepositFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.deposit != null) {
      _amountController.text = widget.deposit!.amount.toStringAsFixed(0);
      _noteController.text = widget.deposit!.note ?? '';
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

    final locale = ref.read(languageProvider);
    final t = (String key, {Map<String, String> params = const {}}) => tr(locale, key, params: params);

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(depositsRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;
      final selectedDate = ref.read(selectedDateProvider);

      if (repository == null || currentUser == null) {
        throw Exception('Repository or user not available');
      }

      final dateStr = formatDateForQuery(selectedDate);
      final deposit = DepositModel(
        id: widget.deposit?.id ?? '',
        amount: double.parse(_amountController.text),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        date: widget.deposit?.date ?? dateStr,
        createdBy: currentUser.uid,
        createdAt: widget.deposit?.createdAt ?? DateTime.now(),
      );

      if (widget.deposit == null) {
        await repository.addDeposit(deposit);
      } else {
        await repository.updateDeposit(deposit);
      }

      // Refresh providers to update UI
      ref.invalidate(depositsByDateProvider);
      ref.invalidate(depositsTotalProvider);
      ref.invalidate(liveCashProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.deposit == null ? t('deposit_added') : t('deposit_updated')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('error_with_message', params: {'message': '$e'}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final t = (String key, {Map<String, String> params = const {}}) => tr(locale, key, params: params);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                widget.deposit == null ? t('new_deposit') : t('edit_deposit'),
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
                  labelText: t('amount_label'),
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  prefixText: '৳ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t('amount_required');
                  }
                  if (double.tryParse(value) == null) {
                    return t('amount_invalid');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Note
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: t('note_optional'),
                  prefixIcon: const Icon(Icons.note_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
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
                            widget.deposit == null ? t('add_deposit') : t('update'),
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
