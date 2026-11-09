import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/localization/strings.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final t = (String key, {Map<String, String> params = const {}}) =>
        tr(locale, key, params: params);
    final salesAsync = ref.watch(salesByDateProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final totals = ref.watch(salesTotalsProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final currentShop = ref.watch(currentShopProvider).value;
    final showProfit =
        currentShop?.showProfit == true && currentUser?.isOwner == true;

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
                    children: [
                      Text(
                        t('sales_title'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Spacer(),
                      _LanguageSwitch(locale: locale),
                      const SizedBox(width: 12),
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
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(selectedDate, t),
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
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
                            label: t('total_sales'),
                            value: CurrencyFormatter.formatNoDecimal(
                              data['totalSales'] ?? 0,
                            ),
                            gradient: AppTheme.successGradient,
                          ),
                        ),
                        if (showProfit) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TotalCard(
                              label: t('total_profit'),
                              value: CurrencyFormatter.formatNoDecimal(
                                data['totalProfit'] ?? 0,
                              ),
                              gradient: AppTheme.purpleGradient,
                              amountColor: Colors.purple,
                            ),
                          ),
                        ],
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(
                      () => _searchQuery = value.trim().toLowerCase(),
                    ),
                    decoration: InputDecoration(
                      hintText: t('search_sales_hint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sales List
            Expanded(
              child: salesAsync.when(
                data: (sales) {
                  // Filter sales based on search query
                  final filteredSales = _searchQuery.isEmpty
                      ? sales
                      : sales.where((sale) {
                          return sale.productName.toLowerCase().contains(
                            _searchQuery,
                          );
                        }).toList();

                  if (filteredSales.isEmpty) {
                    return _searchQuery.isNotEmpty
                        ? _EmptySearchState(query: _searchQuery, locale: locale)
                        : _EmptyState(locale: locale);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredSales.length,
                    itemBuilder: (context, index) {
                      final sale = filteredSales[index];
                      return _SaleCard(
                            sale: sale,
                            showProfit: showProfit,
                            locale: locale,
                            onEdit: () => _showSaleForm(context, sale: sale),
                            onDelete: () => _deleteSale(sale),
                          )
                          .animate()
                          .fadeIn(delay: (100 * index).ms)
                          .slideX(begin: 0.1);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSaleForm(context),
        backgroundColor: AppTheme.successColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(t('add_sale'), style: const TextStyle(color: Colors.white)),
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

  String _formatDate(
    DateTime date,
    String Function(String, {Map<String, String> params}) t,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return t('today');
    if (dateOnly == yesterday) return t('yesterday');
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showSaleForm(BuildContext context, {SaleModel? sale}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SaleFormSheet(sale: sale),
    );
  }

  Future<void> _deleteSale(SaleModel sale) async {
    final locale = ref.read(languageProvider);
    final t = (String key, {Map<String, String> params = const {}}) =>
        tr(locale, key, params: params);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('delete_sale_title')),
        content: Text(t('delete_sale_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(
              t('delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repository = ref.read(salesRepositoryProvider);
      if (repository != null) {
        try {
          await repository.deleteSale(sale);

          // Refresh providers to update UI
          ref.invalidate(salesByDateProvider);
          ref.invalidate(salesTotalsProvider);
          ref.invalidate(depositsByDateProvider);
          ref.invalidate(depositsTotalProvider);
          ref.invalidate(liveCashProvider);

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t('sale_deleted'))));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t('error_with_message', params: {'message': '$e'})),
              ),
            );
          }
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
              color: amountColor ?? AppTheme.successColor,
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
    final t = (String key, {Map<String, String> params = const {}}) =>
        tr(locale, key, params: params);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              size: 64,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t('no_sales_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t('no_sales_sub'),
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
    final t = (String key, {Map<String, String> params = const {}}) =>
        tr(locale, key, params: params);

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
            t('no_results_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t('no_results_sub', params: {'query': query}),
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _LanguageSwitch extends ConsumerWidget {
  const _LanguageSwitch({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(languageProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: locale.languageCode,
          items: const [
            DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (value) {
            if (value != null) {
              notifier.setLanguage(value);
            }
          },
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final SaleModel sale;
  final bool showProfit;
  final Locale locale;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SaleCard({
    required this.sale,
    required this.showProfit,
    required this.locale,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = (String key, {Map<String, String> params = const {}}) =>
        tr(locale, key, params: params);
    final paymentLabel = sale.isCash ? t('cash') : t('bkash');

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
                // Product icon
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: AppTheme.successColor,
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
                        sale.productName,
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
                              color: sale.isCash
                                  ? AppTheme.successColor.withValues(alpha: 0.1)
                                  : AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              paymentLabel,
                              style: TextStyle(
                                fontSize: 9,
                                color: sale.isCash
                                    ? AppTheme.successColor
                                    : AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (showProfit) ...[
                            const SizedBox(width: 6),
                            Text(
                              t(
                                'profit_prefix',
                                params: {
                                  'amount': CurrencyFormatter.formatNoDecimal(
                                    sale.profit,
                                  ),
                                },
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Price and actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatNoDecimal(sale.sellPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.successColor,
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

class _SaleFormSheet extends ConsumerStatefulWidget {
  final SaleModel? sale;

  const _SaleFormSheet({this.sale});

  @override
  ConsumerState<_SaleFormSheet> createState() => _SaleFormSheetState();
}

class _SaleFormSheetState extends ConsumerState<_SaleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _profitController = TextEditingController();
  PaymentType _paymentType = PaymentType.cash;
  bool _isLoading = false;
  String? _selectedProductName;

  @override
  void initState() {
    super.initState();
    if (widget.sale != null) {
      _selectedProductName = widget.sale!.productName.isNotEmpty
          ? widget.sale!.productName
          : null;
      _productNameController.text = widget.sale!.productName;
      _sellPriceController.text = widget.sale!.sellPrice.toStringAsFixed(0);
      _profitController.text = widget.sale!.profit.toStringAsFixed(0);
      _paymentType = widget.sale!.paymentType;
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _sellPriceController.dispose();
    _profitController.dispose();
    super.dispose();
  }

  String paymentLabelFromType(
    String Function(String, {Map<String, String> params}) t,
    PaymentType type,
  ) {
    return type == PaymentType.cash ? t('cash') : t('bkash');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final locale = ref.read(languageProvider);
    final t = (String key, {Map<String, String> params = const {}}) =>
        tr(locale, key, params: params);

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(salesRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;
      final selectedDate = ref.read(selectedDateProvider);

      if (repository == null || currentUser == null) {
        throw Exception('Repository or user not available');
      }

      final dateStr = widget.sale?.date ?? formatDateForQuery(selectedDate);
      final sale = SaleModel(
        id: widget.sale?.id ?? '',
        productName: _selectedProductName ?? _productNameController.text.trim(),
        sellPrice: double.parse(_sellPriceController.text),
        profit: double.tryParse(_profitController.text) ?? 0,
        paymentType: _paymentType,
        date: dateStr,
        createdBy: currentUser.uid,
        createdAt: widget.sale?.createdAt ?? DateTime.now(),
      );

      // A non-cash sale is mirrored by an auto-created deposit
      final autoDeposit = sale.isCash
          ? null
          : DepositModel(
              id: '',
              amount: sale.sellPrice,
              note: t(
                'sale_note',
                params: {
                  'product': sale.productName,
                  'payment': paymentLabelFromType(t, sale.paymentType),
                },
              ),
              date: dateStr,
              createdBy: currentUser.uid,
              createdAt: DateTime.now(),
              isAutoCreated: true,
            );

      if (widget.sale == null) {
        await repository.addSale(sale, autoDeposit: autoDeposit);
      } else {
        await repository.updateSale(
          widget.sale!,
          sale,
          autoDeposit: autoDeposit,
        );
      }

      // Refresh providers to update UI
      ref.invalidate(salesByDateProvider);
      ref.invalidate(salesTotalsProvider);
      ref.invalidate(depositsByDateProvider);
      ref.invalidate(depositsTotalProvider);
      ref.invalidate(liveCashProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.sale == null ? t('sale_added') : t('sale_updated'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('error_with_message', params: {'message': '$e'})),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final t = (String key, {Map<String, String> params = const {}}) =>
        tr(locale, key, params: params);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Allow profit input for all roles so staff can record profit; keep profit visibility restricted elsewhere
    final allowProfitInput = true;

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
              const SizedBox(height: 12),

              // Title
              Text(
                widget.sale == null ? t('new_sale') : t('edit_sale'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Product Name Dropdown/Combo
              Consumer(
                builder: (context, ref, child) {
                  final productsAsync = ref.watch(productsProvider);

                  return productsAsync.when(
                    data: (products) {
                      // Dropdown values must be unique and must include the current value
                      final productNames = {
                        ...products.map((p) => p.name),
                        ?_selectedProductName,
                      }.toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedProductName,
                            decoration: InputDecoration(
                              labelText: t('product_name_optional'),
                              prefixIcon: const Icon(Icons.inventory_2_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(t('select_or_type_product')),
                              ),
                              ...productNames.map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedProductName = value;
                                if (value != null) {
                                  _productNameController.text = value;
                                }
                              });
                            },
                          ),
                          if (_selectedProductName == null) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _productNameController,
                              decoration: InputDecoration(
                                labelText: t('enter_new_product'),
                                prefixIcon: const Icon(Icons.edit_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                helperText: t('optional_hint'),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => TextFormField(
                      controller: _productNameController,
                      decoration: InputDecoration(
                        labelText: t('product_name_optional'),
                        prefixIcon: const Icon(Icons.inventory_2_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    error: (_, __) => TextFormField(
                      controller: _productNameController,
                      decoration: InputDecoration(
                        labelText: t('product_name_optional'),
                        prefixIcon: const Icon(Icons.inventory_2_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Sell Price
              TextFormField(
                controller: _sellPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t('sell_price'),
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  prefixText: '৳ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t('enter_sell_price');
                  }
                  if (double.tryParse(value) == null) {
                    return t('invalid_price');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Profit input (available to staff; profit visibility still owner-only elsewhere)
              if (allowProfitInput) ...[
                TextFormField(
                  controller: _profitController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('profit'),
                    prefixIcon: const Icon(Icons.trending_up_rounded),
                    prefixText: '৳ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Payment Type
              Text(
                t('payment_type'),
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
                      label: t('cash'),
                      icon: Icons.money_rounded,
                      isSelected: _paymentType == PaymentType.cash,
                      onTap: () =>
                          setState(() => _paymentType = PaymentType.cash),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentTypeButton(
                      label: t('bkash'),
                      icon: Icons.credit_card_rounded,
                      isSelected: _paymentType == PaymentType.noncash,
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
                        : Text(
                            widget.sale == null ? t('add') : t('update'),
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
  final VoidCallback onTap;

  const _PaymentTypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
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
          gradient: isSelected ? AppTheme.successGradient : null,
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
