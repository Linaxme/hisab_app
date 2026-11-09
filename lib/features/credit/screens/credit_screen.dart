import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/localization/strings.dart';
import '../../../data/models/models.dart';
import '../../../widgets/entry_form.dart';
import '../../../widgets/modern_widgets.dart';
import '../customer_ledger.dart';

class CreditScreen extends ConsumerStatefulWidget {
  const CreditScreen({super.key});

  @override
  ConsumerState<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends ConsumerState<CreditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showPendingOnly = false;
  bool _ledgerView = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creditSalesAsync = _showPendingOnly
        ? ref.watch(pendingCreditSalesProvider)
        : ref.watch(creditSalesProvider);
    final summaryAsync = ref.watch(creditSummaryProvider);
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
                    title: tr(locale, 'credit_title'),
                    onBack: context.isWide
                        ? null
                        : () => context.canPop() ? context.pop() : context.go('/more'),
                    actions: [
                      DateChip(
                        label: _showPendingOnly
                            ? tr(locale, 'pending_only')
                            : tr(locale, 'all'),
                        icon: _showPendingOnly
                            ? Icons.filter_alt_rounded
                            : Icons.filter_alt_off_rounded,
                        color: _showPendingOnly
                            ? AppTheme.warningColor
                            : AppTheme.primaryColor,
                        showChevron: false,
                        onTap: () => setState(
                          () => _showPendingOnly = !_showPendingOnly,
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.05),
                  const SizedBox(height: 16),
                  // Summary
                  summaryAsync.when(
                    data: (summary) => Column(
                      children: [
                        TotalBanner(
                          label: tr(locale, 'total_credit_label'),
                          value: CurrencyFormatter.formatNoDecimal(
                            summary['totalCredit'] ?? 0,
                          ),
                          icon: Icons.credit_card_rounded,
                          gradient: AppTheme.warningGradient,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                label: 'আদায়',
                                value: CurrencyFormatter.formatNoDecimal(
                                  summary['totalCollected'] ?? 0,
                                ),
                                icon: Icons.check_circle_rounded,
                                color: AppTheme.successColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SummaryCard(
                                label: 'বকেয়া',
                                value: CurrencyFormatter.formatNoDecimal(
                                  summary['remaining'] ?? 0,
                                ),
                                icon: Icons.hourglass_bottom_rounded,
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'নাম বা ফোন নম্বর দিয়ে খুঁজুন...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ).animate().fadeIn(delay: 50.ms),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: Text(tr(locale, 'tx_view')),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.people_alt_rounded, size: 18),
                        label: Text(tr(locale, 'ledger_view')),
                      ),
                    ],
                    selected: {_ledgerView},
                    showSelectedIcon: false,
                    expandedInsets: EdgeInsets.zero,
                    onSelectionChanged: (s) => setState(() => _ledgerView = s.first),
                  ),
                ],
              ),
            ),

            if (_ledgerView)
              Expanded(child: CustomerLedgerView(query: _searchQuery))
            else
            // Credit Sales List
            Expanded(
              child: creditSalesAsync.when(
                data: (creditSales) {
                  // Filter by search query
                  final filteredCredits = _searchQuery.isEmpty
                      ? creditSales
                      : creditSales.where((sale) {
                          final nameMatch =
                              sale.customerName?.toLowerCase().contains(
                                _searchQuery,
                              ) ??
                              false;
                          final phoneMatch =
                              sale.customerPhone?.toLowerCase().contains(
                                _searchQuery,
                              ) ??
                              false;
                          return nameMatch || phoneMatch;
                        }).toList();

                  if (filteredCredits.isEmpty) {
                    return _searchQuery.isNotEmpty
                        ? _EmptySearchState(query: _searchQuery)
                        : _EmptyState();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: filteredCredits.length,
                    itemBuilder: (context, index) {
                      final sale = filteredCredits[index];
                      return _CreditSaleCard(
                            creditSale: sale,
                            onTap: () => _showCreditDetails(context, sale),
                            onAddCollection: () =>
                                _showCollectionForm(context, sale),
                            onDelete: () => _deleteCreditSale(sale),
                          )
                          .animate()
                          .fadeIn(delay: (100 * index).ms)
                          .slideX(begin: 0.1);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('ডেটা লোড করতে সমস্যা হয়েছে')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollectionForm(BuildContext context, CreditSaleModel creditSale) {
    showEntryForm(context, CollectionFormSheet(creditSale: creditSale));
  }

  void _showCreditDetails(BuildContext context, CreditSaleModel creditSale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreditDetailsSheet(creditSale: creditSale),
    );
  }

  Future<void> _deleteCreditSale(CreditSaleModel creditSale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('বাকি মুছুন'),
        content: const Text('এই বাকি এবং সব আদায় মুছে ফেলতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('মুছুন', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repository = ref.read(creditRepositoryProvider);
      if (repository != null) {
        try {
          await repository.deleteCreditSale(creditSale.id);

          // Refresh providers to update UI
          ref.invalidate(creditSalesProvider);
          ref.invalidate(pendingCreditSalesProvider);
          ref.invalidate(creditSummaryProvider);
          ref.invalidate(liveCashProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('বাকি মুছে ফেলা হয়েছে')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
          }
        }
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(context, radius: 16),
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, size: 36, iconSize: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                size: 52,
                color: AppTheme.warningColor,
              ),
            ),
            const SizedBox(height: 24),
            Text('কোনো বাকি নেই', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'বাকি বিক্রয় ট্র্যাক করতে + বাটনে ক্লিক করুন',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }
}

// Empty Search State Widget
class _EmptySearchState extends StatelessWidget {
  final String query;

  const _EmptySearchState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 56,
                color: AppTheme.warningColor.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'কোনো ফলাফল পাওয়া যায়নি',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"$query" এর জন্য কোনো বাকি নেই',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditSaleCard extends StatelessWidget {
  final CreditSaleModel creditSale;
  final VoidCallback onTap;
  final VoidCallback onAddCollection;
  final VoidCallback onDelete;

  const _CreditSaleCard({
    required this.creditSale,
    required this.onTap,
    required this.onAddCollection,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final progress = creditSale.amount > 0
        ? creditSale.collectedAmount / creditSale.amount
        : 0.0;
    final statusColor =
        creditSale.isFullyPaid ? AppTheme.successColor : AppTheme.warningColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(context, radius: 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: creditSale.isFullyPaid
                          ? Icons.check_circle_rounded
                          : Icons.person_rounded,
                      color: statusColor,
                      size: 42,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 12),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creditSale.customerName ?? 'অজানা গ্রাহক',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (creditSale.customerPhone != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              creditSale.customerPhone!,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatNoDecimal(creditSale.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusPill(
                          label: creditSale.isFullyPaid
                              ? 'পরিশোধিত'
                              : 'বকেয়া ${CurrencyFormatter.formatNoDecimal(creditSale.remainingAmount)}',
                          color: creditSale.isFullyPaid
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: statusColor.withValues(
                      alpha: isDark ? 0.18 : 0.12,
                    ),
                    valueColor: AlwaysStoppedAnimation(statusColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_rounded,
                          size: 13,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${creditSale.date} · ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!creditSale.isFullyPaid)
                          TextButton.icon(
                            onPressed: onAddCollection,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text(
                              'আদায়',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.successColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          color: AppTheme.errorColor,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'মুছুন',
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

class CreditSaleFormSheet extends ConsumerStatefulWidget {
  final CreditSaleModel? creditSale;

  const CreditSaleFormSheet({super.key, this.creditSale});

  @override
  ConsumerState<CreditSaleFormSheet> createState() =>
      _CreditSaleFormSheetState();
}

class _CreditSaleFormSheetState extends ConsumerState<CreditSaleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.creditSale != null) {
      _customerNameController.text = widget.creditSale!.customerName ?? '';
      _customerPhoneController.text = widget.creditSale!.customerPhone ?? '';
      _amountController.text = widget.creditSale!.amount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final collected = widget.creditSale?.collectedAmount ?? 0;
    if (double.parse(_amountController.text) < collected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('বাকির পরিমাণ আদায়ের চেয়ে কম হতে পারে না')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(creditRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;
      final selectedDate = ref.read(selectedDateProvider);

      if (repository == null || currentUser == null) {
        throw Exception('Repository or user not available');
      }

      final dateStr = formatDateForQuery(selectedDate);
      final creditSale = CreditSaleModel(
        id: widget.creditSale?.id ?? '',
        customerName: _customerNameController.text.trim().isEmpty
            ? null
            : _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim().isEmpty
            ? null
            : _customerPhoneController.text.trim(),
        amount: double.parse(_amountController.text),
        collectedAmount: widget.creditSale?.collectedAmount ?? 0,
        date: widget.creditSale?.date ?? dateStr,
        createdBy: currentUser.uid,
        createdAt: widget.creditSale?.createdAt ?? DateTime.now(),
      );

      if (widget.creditSale == null) {
        await repository.addCreditSale(creditSale);
      } else {
        await repository.updateCreditSale(creditSale);
      }

      // Refresh providers to update UI
      ref.invalidate(creditSalesProvider);
      ref.invalidate(pendingCreditSalesProvider);
      ref.invalidate(creditSummaryProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.creditSale == null
                  ? 'বাকি যোগ হয়েছে'
                  : 'বাকি আপডেট হয়েছে',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 12),

              // Title
              Text(
                widget.creditSale == null ? 'নতুন বাকি' : 'বাকি সম্পাদনা',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Customer Name
              TextFormField(
                controller: _customerNameController,
                decoration: InputDecoration(
                  labelText: 'গ্রাহকের নাম (ঐচ্ছিক)',
                  prefixIcon: const Icon(Icons.person_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Customer Phone
              TextFormField(
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'ফোন নম্বর (ঐচ্ছিক)',
                  prefixIcon: const Icon(Icons.phone_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'পরিমাণ',
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  prefixText: '৳ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'পরিমাণ দিন';
                  }
                  if (double.tryParse(value) == null) {
                    return 'সঠিক পরিমাণ দিন';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.warningGradient,
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
                            widget.creditSale == null
                                ? 'যোগ করুন'
                                : 'আপডেট করুন',
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

class CollectionFormSheet extends ConsumerStatefulWidget {
  final CreditSaleModel creditSale;

  const CollectionFormSheet({super.key, required this.creditSale});

  @override
  ConsumerState<CollectionFormSheet> createState() =>
      _CollectionFormSheetState();
}

class _CollectionFormSheetState extends ConsumerState<CollectionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);
    if (amount > widget.creditSale.remainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('আদায় বকেয়ার চেয়ে বেশি হতে পারে না')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(creditRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;
      final selectedDate = ref.read(selectedDateProvider);

      if (repository == null || currentUser == null) {
        throw Exception('Repository or user not available');
      }

      final dateStr = formatDateForQuery(selectedDate);
      final collection = CreditCollectionModel(
        id: '',
        creditSaleId: widget.creditSale.id,
        amount: amount,
        date: dateStr,
        createdBy: currentUser.uid,
        createdAt: DateTime.now(),
      );

      await repository.addCollection(collection);

      // Refresh providers to update UI
      ref.invalidate(creditSalesProvider);
      ref.invalidate(pendingCreditSalesProvider);
      ref.invalidate(creditSummaryProvider);
      ref.invalidate(liveCashProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('আদায় যোগ হয়েছে')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'আদায় যোগ করুন',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'বকেয়া: ${CurrencyFormatter.formatNoDecimal(widget.creditSale.remainingAmount)}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'আদায় পরিমাণ',
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  prefixText: '৳ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: TextButton(
                    onPressed: () {
                      _amountController.text = widget.creditSale.remainingAmount
                          .toStringAsFixed(0);
                    },
                    child: const Text('সব'),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'পরিমাণ দিন';
                  }
                  if (double.tryParse(value) == null) {
                    return 'সঠিক পরিমাণ দিন';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.successGradient,
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
                        : const Text(
                            'আদায় করুন',
                            style: TextStyle(
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

class _CreditDetailsSheet extends ConsumerWidget {
  final CreditSaleModel creditSale;

  const _CreditDetailsSheet({required this.creditSale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repository = ref.watch(creditRepositoryProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 20),

                // Customer info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.warningColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creditSale.customerName ?? 'অজানা গ্রাহক',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (creditSale.customerPhone != null)
                            Text(
                              creditSale.customerPhone!,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'মোট বাকি',
                        value: CurrencyFormatter.formatNoDecimal(
                          creditSale.amount,
                        ),
                      ),
                      const Divider(),
                      _DetailRow(
                        label: 'আদায়',
                        value: CurrencyFormatter.formatNoDecimal(
                          creditSale.collectedAmount,
                        ),
                        valueColor: AppTheme.successColor,
                      ),
                      const Divider(),
                      _DetailRow(
                        label: 'বকেয়া',
                        value: CurrencyFormatter.formatNoDecimal(
                          creditSale.remainingAmount,
                        ),
                        valueColor: AppTheme.errorColor,
                      ),
                      const Divider(),
                      _DetailRow(label: 'তারিখ', value: creditSale.date),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Collections list
                Text(
                  'আদায়ের ইতিহাস',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (repository != null)
                  StreamBuilder<List<CreditCollectionModel>>(
                    stream: repository.watchCollectionsForSale(creditSale.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final collections = snapshot.data ?? [];

                      if (collections.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkCard
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'কোনো আদায় নেই',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: collections.length,
                        itemBuilder: (context, index) {
                          final collection = collections[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkCard
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      CurrencyFormatter.formatNoDecimal(
                                        collection.amount,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.successColor,
                                      ),
                                    ),
                                    Text(
                                      collection.date,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () async {
                                    try {
                                      await repository.deleteCollection(
                                        collection.id,
                                        collection.creditSaleId,
                                        collection.amount,
                                      );
                                      ref.invalidate(creditSummaryProvider);
                                      ref.invalidate(liveCashProvider);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('ত্রুটি: $e')),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    size: 20,
                                  ),
                                  color: AppTheme.errorColor,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }
}
