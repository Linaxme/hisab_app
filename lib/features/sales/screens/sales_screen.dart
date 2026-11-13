import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/localization/strings.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../../widgets/amount_keypad.dart';
import '../../../widgets/entry_form.dart';
import '../../../widgets/modern_widgets.dart';
import '../../stock/stock_forms.dart' show formatQty;

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
                  ScreenHeader(
                    title: t('sales_title'),
                    actions: [
                      DateChip(
                        label: _formatDate(selectedDate, t),
                        onTap: () => _selectDate(context, ref),
                        color: AppTheme.successColor,
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.05),
                  const SizedBox(height: 16),

                  // Totals banner
                  totals.when(
                    data: (data) => TotalBanner(
                      label: t('total_sales'),
                      value: CurrencyFormatter.formatNoDecimal(
                        data['totalSales'] ?? 0,
                      ),
                      icon: Icons.point_of_sale_rounded,
                      gradient: AppTheme.successGradient,
                      trailingLabel: showProfit ? t('total_profit') : null,
                      trailingValue: showProfit
                          ? CurrencyFormatter.formatNoDecimal(
                              data['totalProfit'] ?? 0,
                            )
                          : null,
                    ).animate().fadeIn(delay: 100.ms),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
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
                          .fadeIn(delay: (40 * index.clamp(0, 8)).ms)
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
    );
  }

  Future<void> _selectDate(BuildContext context, WidgetRef ref) async {
    final selectedDate = ref.read(selectedDateProvider);
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
    showEntryForm(context, SaleFormSheet(sale: sale));
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
    final t = (String key, {Map<String, String> params = const {}}) =>
        tr(locale, key, params: params);
    final paymentLabel = sale.isCash ? t('cash') : t('digital');

    return EntryCard(
      icon: Icons.shopping_bag_rounded,
      color: AppTheme.successColor,
      title: sale.productName.isEmpty ? t('sales_title') : sale.productName,
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusPill(
            label: paymentLabel,
            color: sale.isCash ? AppTheme.successColor : AppTheme.infoColor,
            icon: sale.isCash ? Icons.payments_rounded : Icons.phone_android_rounded,
          ),
          if (showProfit)
            Text(
              t(
                'profit_prefix',
                params: {'amount': CurrencyFormatter.formatNoDecimal(sale.profit)},
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      amount: CurrencyFormatter.formatNoDecimal(sale.sellPrice),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

enum _AmountField { price, profit }

/// Calculator-style sale entry: big amount, product chips and a number pad.
class SaleFormSheet extends ConsumerStatefulWidget {
  final SaleModel? sale;

  const SaleFormSheet({super.key, this.sale});

  @override
  ConsumerState<SaleFormSheet> createState() => _SaleFormSheetState();
}

class _SaleFormSheetState extends ConsumerState<SaleFormSheet> {
  final _productController = TextEditingController();
  final _productFocus = FocusNode();
  final _keyboardFocus = FocusNode();
  String _price = '';
  String _profit = '';
  _AmountField _active = _AmountField.price;
  PaymentType _paymentType = PaymentType.cash;
  String? _selectedProduct;
  bool _typingProduct = false;
  bool _isLoading = false;
  bool _showError = false;
  int _savedCount = 0;
  double _qty = 1;

  bool get _isEdit => widget.sale != null;

  static String _digits(double value) => value > 0 ? value.toStringAsFixed(0) : '';

  @override
  void initState() {
    super.initState();
    final sale = widget.sale;
    if (sale != null) {
      _price = _digits(sale.sellPrice);
      _profit = _digits(sale.profit);
      _paymentType = sale.paymentType;
      _selectedProduct = sale.productName.isNotEmpty ? sale.productName : null;
      _qty = sale.quantity ?? 1;
    }
  }

  /// The stocked product behind the selected chip, while the Stock add-on is on.
  ProductModel? get _stockProduct {
    if (_typingProduct || _selectedProduct == null || !ref.read(stockAddonActiveProvider)) return null;
    final tracked = ref.read(stockProductsProvider);
    final originalId = widget.sale?.productId;
    if (originalId != null && widget.sale!.productName == _selectedProduct) {
      final byId = tracked.where((p) => p.id == originalId).firstOrNull;
      if (byId != null) return byId;
    }
    return tracked.where((p) => p.name == _selectedProduct).firstOrNull;
  }

  /// Price and profit follow quantity × the product's prices when those are set.
  void _applyStockPrices() {
    final product = _stockProduct;
    if (product == null || product.sellPrice == null) return;
    final sell = product.sellPrice! * _qty;
    _price = _digits(sell.roundToDouble());
    _profit = product.buyPrice == null ? _profit : _digits((sell - product.buyPrice! * _qty).roundToDouble());
    _showError = false;
  }

  void _setQty(double qty) {
    if (qty <= 0) return;
    setState(() {
      _qty = qty;
      _applyStockPrices();
    });
  }

  Future<void> _editQty(ProductModel product) async {
    final controller = TextEditingController(text: formatQty(_qty));
    final qty = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('পরিমাণ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))],
          decoration: InputDecoration(suffixText: product.unit),
          onSubmitted: (v) => Navigator.pop(context, double.tryParse(v.trim())),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text.trim())),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (qty != null) _setQty(qty);
    _keyboardFocus.requestFocus();
  }

  @override
  void dispose() {
    _productController.dispose();
    _productFocus.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _press(String key) {
    setState(() {
      _showError = false;
      if (_active == _AmountField.price) {
        _price = applyKeypadKey(_price, key);
      } else {
        _profit = applyKeypadKey(_profit, key);
      }
    });
  }

  void _clearActive() {
    setState(() {
      if (_active == _AmountField.price) {
        _price = '';
      } else {
        _profit = '';
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_productFocus.hasFocus) return KeyEventResult.ignored;
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      _save();
      return KeyEventResult.handled;
    }
    final key = keypadKeyFor(event);
    if (key == null) return KeyEventResult.ignored;
    _press(key);
    return KeyEventResult.handled;
  }

  String get _productName =>
      _typingProduct ? _productController.text.trim() : (_selectedProduct ?? '');

  Future<void> _save({bool next = false}) async {
    if (_isLoading) return;
    final locale = ref.read(languageProvider);
    String t(String key, {Map<String, String> params = const {}}) =>
        tr(locale, key, params: params);

    final price = double.tryParse(_price) ?? 0;
    if (price <= 0) {
      setState(() {
        _showError = true;
        _active = _AmountField.price;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(salesRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;
      final selectedDate = ref.read(selectedDateProvider);

      if (repository == null || currentUser == null) {
        throw Exception('Repository or user not available');
      }

      final dateStr = widget.sale?.date ?? formatDateForQuery(selectedDate);
      final stockProduct = _stockProduct;
      // With the add-on off, an edit keeps the sale's old stock link untouched.
      final keepOld = stockProduct == null && !ref.read(stockAddonActiveProvider);
      final sale = SaleModel(
        id: widget.sale?.id ?? '',
        productName: _productName,
        sellPrice: price,
        profit: double.tryParse(_profit) ?? 0,
        paymentType: _paymentType,
        date: dateStr,
        createdBy: currentUser.uid,
        createdAt: widget.sale?.createdAt ?? DateTime.now(),
        productId: stockProduct?.id ?? (keepOld ? widget.sale?.productId : null),
        quantity: stockProduct != null ? _qty : (keepOld ? widget.sale?.quantity : null),
      );

      // A digital sale is mirrored by an auto-created deposit
      final autoDeposit = sale.isCash
          ? null
          : DepositModel(
              id: '',
              amount: sale.sellPrice,
              note: t('sale_note', params: {'product': sale.productName, 'payment': t('digital')}),
              date: dateStr,
              createdBy: currentUser.uid,
              createdAt: DateTime.now(),
              isAutoCreated: true,
            );

      if (_isEdit) {
        await repository.updateSale(widget.sale!, sale, autoDeposit: autoDeposit);
      } else {
        await repository.addSale(sale, autoDeposit: autoDeposit);
      }

      if (!mounted) return;
      if (next) {
        setState(() {
          _price = '';
          _profit = '';
          _active = _AmountField.price;
          _selectedProduct = null;
          _typingProduct = false;
          _qty = 1;
          _productController.clear();
          _savedCount++;
        });
        _keyboardFocus.requestFocus();
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? t('sale_updated') : t('sale_added'))),
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

  List<String> _productChips() {
    final today = ref.watch(salesByDateProvider).valueOrNull ?? const <SaleModel>[];
    final products = ref.watch(productsProvider).valueOrNull ?? const <ProductModel>[];
    return {
      ?_selectedProduct,
      for (final s in today)
        if (s.productName.isNotEmpty) s.productName,
      for (final p in products)
        if (p.active) p.name,
    }.toList();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    String t(String key) => tr(locale, key);
    final digital = _paymentType == PaymentType.noncash;
    final accent = digital ? AppTheme.infoColor : AppTheme.successColor;
    final chips = _productChips();
    ref.watch(stockProductsProvider);
    ref.watch(stockAddonActiveProvider);
    final stockProduct = _stockProduct;

    return Focus(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                Row(
                  children: [
                    Text(
                      _isEdit ? t('edit_sale') : t('new_sale'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    if (_savedCount > 0)
                      StatusPill(
                        label: '✓ $_savedCount',
                        color: AppTheme.successColor,
                      ).animate(key: ValueKey(_savedCount)).scale(curve: Curves.easeOutBack),
                  ],
                ),
                const SizedBox(height: 14),

                // Amount display
                _AmountDisplay(
                  priceLabel: t('sell_price'),
                  profitLabel: t('profit'),
                  price: _price,
                  profit: _profit,
                  active: _active,
                  accent: accent,
                  error: _showError ? t('enter_sell_price') : null,
                  onSelect: (field) => setState(() => _active = field),
                ),
                const SizedBox(height: 14),

                // Product chips
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _Chip(
                        label: t('new_product'),
                        icon: Icons.add_rounded,
                        selected: _typingProduct,
                        onTap: () {
                          setState(() {
                            _typingProduct = !_typingProduct;
                            if (_typingProduct) _selectedProduct = null;
                          });
                          if (_typingProduct) _productFocus.requestFocus();
                        },
                      ),
                      for (final name in chips)
                        _Chip(
                          label: name,
                          selected: !_typingProduct && _selectedProduct == name,
                          onTap: () => setState(() {
                            _typingProduct = false;
                            _selectedProduct = _selectedProduct == name ? null : name;
                            _qty = 1;
                            _applyStockPrices();
                          }),
                        ),
                    ],
                  ),
                ),
                if (stockProduct != null) ...[
                  const SizedBox(height: 10),
                  _QuantityRow(
                    product: stockProduct,
                    qty: _qty,
                    onChanged: _setQty,
                    onEdit: () => _editQty(stockProduct),
                  ),
                ],
                if (_typingProduct) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _productController,
                    focusNode: _productFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _keyboardFocus.requestFocus(),
                    decoration: InputDecoration(
                      hintText: t('enter_new_product'),
                      prefixIcon: const Icon(Icons.inventory_2_rounded),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Payment type
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _PaymentSegment(
                        label: t('cash'),
                        icon: Icons.payments_rounded,
                        color: AppTheme.successColor,
                        selected: !digital,
                        onTap: () => setState(() => _paymentType = PaymentType.cash),
                      ),
                      _PaymentSegment(
                        label: t('digital'),
                        icon: Icons.phone_android_rounded,
                        color: AppTheme.infoColor,
                        selected: digital,
                        onTap: () => setState(() => _paymentType = PaymentType.noncash),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                AmountKeypad(onKey: _press, onClear: _clearActive),
                const SizedBox(height: 14),

                // Actions
                Row(
                  children: [
                    if (!_isEdit) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => _save(next: true),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                            foregroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            t('save_and_next'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppTheme.onPrimary,
                                ),
                              )
                            : Text(
                                _isEdit ? t('update') : t('save'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                      ),
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

/// − qty + for a stocked product; tapping the number allows decimals (e.g. 2.5 kg).
class _QuantityRow extends StatelessWidget {
  final ProductModel product;
  final double qty;
  final ValueChanged<double> onChanged;
  final VoidCallback onEdit;

  const _QuantityRow({
    required this.product,
    required this.qty,
    required this.onChanged,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final low = product.isLowStock;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('পরিমাণ', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  'স্টকে ${formatQty(product.stockQty)} ${product.unit}'
                  '${product.sellPrice != null ? ' · ৳${formatQty(product.sellPrice!)}/${product.unit}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: low ? AppTheme.errorColor : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: qty > 1 ? () => onChanged(qty - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                '${formatQty(qty)} ${product.unit}',
                style: AppTheme.numeric(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => onChanged(qty + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  final String priceLabel;
  final String profitLabel;
  final String price;
  final String profit;
  final _AmountField active;
  final Color accent;
  final String? error;
  final ValueChanged<_AmountField> onSelect;

  const _AmountDisplay({
    required this.priceLabel,
    required this.profitLabel,
    required this.price,
    required this.profit,
    required this.active,
    required this.accent,
    required this.error,
    required this.onSelect,
  });

  static String _format(String digits) =>
      CurrencyFormatter.formatNoDecimal(double.tryParse(digits) ?? 0);

  @override
  Widget build(BuildContext context) {
    final priceActive = active == _AmountField.price;
    final borderColor = error != null
        ? AppTheme.errorColor
        : (priceActive ? accent : Colors.white.withValues(alpha: 0.08));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.12), AppTheme.darkCard],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: priceActive ? 1.5 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(_AmountField.price),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error ?? priceLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: error != null ? AppTheme.errorColor : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _format(price),
                      style: AppTheme.numeric(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        color: price.isEmpty ? AppTheme.textSecondary.withValues(alpha: 0.5) : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => onSelect(_AmountField.profit),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.violetColor.withValues(alpha: priceActive ? 0.08 : 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: priceActive
                      ? AppTheme.violetColor.withValues(alpha: 0.25)
                      : AppTheme.violetColor,
                  width: priceActive ? 1 : 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    profitLabel,
                    style: const TextStyle(fontSize: 11, color: AppTheme.violetColor, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _format(profit),
                    style: AppTheme.numeric(fontSize: 16, color: AppTheme.violetColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppTheme.onPrimary : AppTheme.darkTextPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppTheme.primaryColor : AppTheme.darkCard,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: selected ? fg : AppTheme.primaryColor),
                  const SizedBox(width: 4),
                ],
                Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentSegment({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppTheme.onPrimary : AppTheme.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? AppTheme.softShadow(color) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

