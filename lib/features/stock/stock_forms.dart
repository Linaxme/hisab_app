import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../widgets/app_panel.dart';

const stockUnits = ['পিস', 'কেজি', 'লিটার', 'প্যাকেট', 'ডজন', 'বস্তা'];

/// 12 → "12", 2.5 → "2.5", 0.333 → "0.33"
String formatQty(double qty) {
  if (qty == qty.roundToDouble()) return qty.toStringAsFixed(0);
  return qty.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

final _decimalInput = [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,3}'))];

double? _parse(TextEditingController c) => double.tryParse(c.text.trim());

InputDecoration _field(String label, {String? suffix, String? prefix, String? helper}) =>
    InputDecoration(labelText: label, suffixText: suffix, prefixText: prefix, helperText: helper);

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> showStockProductForm(BuildContext context, {ProductModel? product}) {
  return showAppPanel(context, _StockProductForm(product: product));
}

Future<void> showStockInForm(BuildContext context, {ProductModel? product}) {
  return showAppPanel(context, _StockInForm(product: product));
}

Future<void> showStockCountForm(BuildContext context, ProductModel product) {
  return showAppPanel(context, _StockCountForm(product: product));
}

/// Adds a stocked product, turns stock on for an existing one, or edits its settings.
class _StockProductForm extends ConsumerStatefulWidget {
  final ProductModel? product;

  const _StockProductForm({this.product});

  @override
  ConsumerState<_StockProductForm> createState() => _StockProductFormState();
}

class _StockProductFormState extends ConsumerState<_StockProductForm> {
  final _name = TextEditingController();
  final _buy = TextEditingController();
  final _sell = TextEditingController();
  final _low = TextEditingController();
  final _qty = TextEditingController();
  final _customUnit = TextEditingController();
  String _unit = stockUnits.first;
  ProductModel? _existing;
  bool _saving = false;

  bool get _isEdit => widget.product?.trackStock == true;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) _fill(p);
  }

  void _fill(ProductModel p) {
    _existing = p;
    _name.text = p.name;
    String num(double? v) => v == null ? '' : formatQty(v);
    _buy.text = num(p.buyPrice);
    _sell.text = num(p.sellPrice);
    _low.text = num(p.lowStockAt);
    if (stockUnits.contains(p.unit)) {
      _unit = p.unit;
    } else {
      _unit = '';
      _customUnit.text = p.unit;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _buy, _sell, _low, _qty, _customUnit]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({bool stopTracking = false}) async {
    final name = _name.text.trim();
    final unit = _unit.isEmpty ? _customUnit.text.trim() : _unit;
    if (name.isEmpty || unit.isEmpty) {
      _snack(context, 'পণ্যের নাম আর একক দিন');
      return;
    }
    final repository = ref.read(productsRepositoryProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (repository == null || user == null) return;

    setState(() => _saving = true);
    final today = formatDateForQuery(DateTime.now());
    final settings = ProductModel(
      id: _existing?.id ?? '',
      name: name,
      createdAt: DateTime.now(),
      trackStock: !stopTracking,
      stockQty: _parse(_qty) ?? 0,
      unit: unit,
      buyPrice: _parse(_buy),
      sellPrice: _parse(_sell),
      lowStockAt: _parse(_low),
    );
    try {
      final existing = _existing;
      if (existing == null) {
        await repository.addStockProduct(settings, createdBy: user.uid, date: today);
      } else {
        await repository.updateStockSettings(settings);
        final opening = _parse(_qty);
        if (!_isEdit && opening != null) {
          await repository.setStockCount(existing, opening,
              createdBy: user.uid, date: today, note: 'শুরুর স্টক');
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack(context, 'সেভ করা যায়নি: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final untracked = (ref.watch(productsProvider).valueOrNull ?? const <ProductModel>[])
        .where((p) => !p.trackStock)
        .toList();
    final unitLabel = _unit.isEmpty ? _customUnit.text.trim() : _unit;

    return AppPanelFrame(
      title: _isEdit ? 'স্টকের তথ্য' : 'স্টকে পণ্য যোগ',
      subtitle: _isEdit ? widget.product!.name : 'নতুন পণ্য, বা আগের পণ্যে স্টক চালু করুন',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isEdit && untracked.isNotEmpty && widget.product == null) ...[
              DropdownButtonFormField<String>(
                initialValue: _existing?.id ?? '',
                isExpanded: true,
                decoration: _field('আগের পণ্য থেকে বাছাই (ঐচ্ছিক)'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('— নতুন পণ্য —')),
                  for (final p in untracked) DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (id) => setState(() {
                  final p = untracked.where((p) => p.id == id).firstOrNull;
                  if (p == null) {
                    _existing = null;
                    _name.clear();
                  } else {
                    _fill(p);
                  }
                }),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _name,
              decoration: _field('পণ্যের নাম'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Text('একক', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in stockUnits)
                  ChoiceChip(
                    label: Text(u),
                    selected: _unit == u,
                    onSelected: (_) => setState(() => _unit = u),
                  ),
                ChoiceChip(
                  label: const Text('অন্য'),
                  selected: _unit.isEmpty,
                  onSelected: (_) => setState(() => _unit = ''),
                ),
              ],
            ),
            if (_unit.isEmpty) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customUnit,
                decoration: _field('একক লিখুন (যেমন গজ)'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buy,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _decimalInput,
                    decoration: _field('কেনা দাম', prefix: '৳ ', helper: unitLabel.isEmpty ? null : 'প্রতি $unitLabel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _sell,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _decimalInput,
                    decoration: _field('বিক্রি দাম', prefix: '৳ ', helper: unitLabel.isEmpty ? null : 'প্রতি $unitLabel'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!_isEdit) ...[
                  Expanded(
                    child: TextField(
                      controller: _qty,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: _decimalInput,
                      decoration: _field('এখন স্টকে আছে', suffix: unitLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextField(
                    controller: _low,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _decimalInput,
                    decoration: _field('কত হলে সতর্ক করবে', suffix: unitLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_saving ? 'সেভ হচ্ছে…' : 'সেভ করুন'),
            ),
            if (_isEdit && ref.watch(currentUserProvider).valueOrNull?.isOwner == true) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : () => _save(stopTracking: true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                child: const Text('এই পণ্যের স্টক গোনা বন্ধ করুন'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Goods received: adds to stock and updates the buy price.
class _StockInForm extends ConsumerStatefulWidget {
  final ProductModel? product;

  const _StockInForm({this.product});

  @override
  ConsumerState<_StockInForm> createState() => _StockInFormState();
}

class _StockInFormState extends ConsumerState<_StockInForm> {
  final _qty = TextEditingController();
  final _buy = TextEditingController();
  final _note = TextEditingController();
  ProductModel? _product;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _select(widget.product);
  }

  void _select(ProductModel? p) {
    _product = p;
    _buy.text = p?.buyPrice == null ? '' : formatQty(p!.buyPrice!);
  }

  @override
  void dispose() {
    _qty.dispose();
    _buy.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final product = _product;
    final qty = _parse(_qty);
    if (product == null || qty == null || qty <= 0) {
      _snack(context, 'পণ্য আর পরিমাণ দিন');
      return;
    }
    final repository = ref.read(productsRepositoryProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (repository == null || user == null) return;

    setState(() => _saving = true);
    try {
      await repository.addStockEntry(StockEntryModel(
        id: '',
        productId: product.id,
        productName: product.name,
        type: 'in',
        quantity: qty,
        buyPrice: _parse(_buy),
        note: _note.text.trim(),
        date: formatDateForQuery(DateTime.now()),
        createdBy: user.uid,
        createdAt: DateTime.now(),
      ));
      if (mounted) {
        Navigator.pop(context);
        _snack(context, '${product.name}: ${formatQty(qty)} ${product.unit} স্টকে যোগ হয়েছে');
      }
    } catch (e) {
      if (mounted) _snack(context, 'সেভ করা যায়নি: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(stockProductsProvider);
    final selected = products.where((p) => p.id == _product?.id).firstOrNull ?? _product;
    final unit = selected?.unit ?? '';
    final qty = _parse(_qty) ?? 0;
    final buy = _parse(_buy) ?? 0;

    return AppPanelFrame(
      title: 'মাল এসেছে',
      subtitle: 'স্টকে যোগ হবে, খরচে যোগ হবে না',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selected?.id,
              isExpanded: true,
              decoration: _field('পণ্য'),
              items: [
                for (final p in products)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.name}  (${formatQty(p.stockQty)} ${p.unit})'),
                  ),
              ],
              onChanged: (id) => setState(() => _select(products.firstWhere((p) => p.id == id))),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qty,
                    autofocus: widget.product != null,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _decimalInput,
                    decoration: _field('পরিমাণ', suffix: unit),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _buy,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _decimalInput,
                    decoration: _field('কেনা দাম', prefix: '৳ ', helper: unit.isEmpty ? null : 'প্রতি $unit'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (qty > 0 && buy > 0) ...[
              const SizedBox(height: 8),
              Text(
                'মোট কেনা: ৳${formatQty(qty * buy)}',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: _field('নোট (ঐচ্ছিক, যেমন সাপ্লায়ারের নাম)')),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_saving ? 'সেভ হচ্ছে…' : 'স্টকে যোগ করুন'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Counted stock differs from the app: set it to the counted amount.
class _StockCountForm extends ConsumerStatefulWidget {
  final ProductModel product;

  const _StockCountForm({required this.product});

  @override
  ConsumerState<_StockCountForm> createState() => _StockCountFormState();
}

class _StockCountFormState extends ConsumerState<_StockCountForm> {
  late final _qty = TextEditingController(text: formatQty(widget.product.stockQty));
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final counted = _parse(_qty);
    if (counted == null || counted < 0) {
      _snack(context, 'গোনা পরিমাণ দিন');
      return;
    }
    final repository = ref.read(productsRepositoryProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (repository == null || user == null) return;

    setState(() => _saving = true);
    try {
      await repository.setStockCount(widget.product, counted,
          createdBy: user.uid,
          date: formatDateForQuery(DateTime.now()),
          note: _note.text.trim().isEmpty ? 'গুনে ঠিক করা' : _note.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack(context, 'সেভ করা যায়নি: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final counted = _parse(_qty);
    final diff = counted == null ? null : counted - p.stockQty;

    return AppPanelFrame(
      title: 'স্টক গুনে ঠিক করুন',
      subtitle: '${p.name} · অ্যাপে আছে ${formatQty(p.stockQty)} ${p.unit}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _qty,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _decimalInput,
            decoration: _field('গুনে পাওয়া গেছে', suffix: p.unit),
            onChanged: (_) => setState(() {}),
          ),
          if (diff != null && diff != 0) ...[
            const SizedBox(height: 8),
            Text(
              diff > 0 ? '${formatQty(diff)} ${p.unit} বেশি পাওয়া গেছে' : '${formatQty(-diff)} ${p.unit} কম পাওয়া গেছে',
              style: TextStyle(color: diff > 0 ? AppTheme.successColor : AppTheme.errorColor),
            ),
          ],
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: _field('কারণ (ঐচ্ছিক, যেমন নষ্ট হয়েছে)')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_saving ? 'সেভ হচ্ছে…' : 'ঠিক করুন'),
          ),
        ],
      ),
    );
  }
}
