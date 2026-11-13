import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/models.dart';
import '../../../widgets/app_panel.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/modern_widgets.dart';
import '../stock_forms.dart';

String formatDayMonthYear(DateTime d) => '${d.day}/${d.month}/${d.year}';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(shopPremiumProvider);
    final active = ref.watch(stockAddonActiveProvider);
    final until = premium.valueOrNull?.stockUntil;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: ScreenHeader(
                title: 'স্টক',
                subtitle: active && until != null ? 'চালু আছে ${formatDayMonthYear(until)} পর্যন্ত' : null,
                onBack: context.isWide
                    ? null
                    : () => context.canPop() ? context.pop() : context.go('/more'),
                actions: [
                  if (active) ...[
                    IconButton.filledTonal(
                      tooltip: 'স্টকে পণ্য যোগ',
                      onPressed: () => showStockProductForm(context),
                      icon: const Icon(Icons.add_rounded),
                    ),
                    FilledButton.icon(
                      onPressed: () => showStockInForm(context),
                      icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
                      label: const Text('মাল এসেছে'),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: premium.isLoading && !premium.hasValue
                  ? const Center(child: CircularProgressIndicator())
                  : active
                      ? const _StockList()
                      : _LockedView(expiredOn: until),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedView extends ConsumerWidget {
  final DateTime? expiredOn;

  const _LockedView({this.expiredOn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(currentUserProvider).valueOrNull?.isOwner ?? false;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              const IconBadge(
                icon: Icons.inventory_rounded,
                color: AppTheme.primaryColor,
                gradient: AppTheme.primaryGradient,
                size: 72,
                iconSize: 36,
              ),
              const SizedBox(height: 18),
              Text('স্টক অ্যাড-অন', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'প্রতিটা পণ্যের স্টক, কেনা ও বিক্রি দাম, বিক্রি করলে স্টক নিজে থেকে কমে যাওয়া, আর স্টক কমে গেলে সতর্কবার্তা।',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              StatusPill(
                label: expiredOn == null
                    ? 'এই দোকানে চালু নেই'
                    : 'মেয়াদ শেষ হয়েছে ${formatDayMonthYear(expiredOn!)}',
                color: AppTheme.warningColor,
                icon: Icons.lock_rounded,
              ),
              if (kIsWeb && isOwner) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.push('/premium'),
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('চালু করুন'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StockList extends ConsumerStatefulWidget {
  const _StockList();

  @override
  ConsumerState<_StockList> createState() => _StockListState();
}

class _StockListState extends ConsumerState<_StockList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(stockProductsProvider);
    final loading = ref.watch(productsProvider).isLoading;
    if (loading && products.isEmpty) return const Center(child: CircularProgressIndicator());
    if (products.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'স্টকে কোনো পণ্য নেই',
        message: 'উপরের + দিয়ে নতুন পণ্য যোগ করুন, বা আগের পণ্যে স্টক চালু করুন',
      );
    }

    final low = products.where((p) => p.isLowStock).length;
    final value = products.fold<double>(0, (s, p) => s + p.stockValue);
    final shown = _query.isEmpty
        ? products
        : products.where((p) => p.name.toLowerCase().contains(_query)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        TotalBanner(
          label: 'স্টকের মোট মূল্য (কেনা দামে)',
          value: CurrencyFormatter.formatNoDecimal(value),
          icon: Icons.inventory_rounded,
          gradient: AppTheme.primaryGradient,
          trailingLabel: low > 0 ? 'স্টক কম' : 'পণ্য',
          trailingValue: low > 0 ? '$lowটি' : '${products.length}টি',
        ).animate().fadeIn(),
        const SizedBox(height: 12),
        if (products.length > 6) ...[
          TextField(
            decoration: const InputDecoration(
              hintText: 'পণ্য খুঁজুন',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
        ],
        for (final p in shown)
          EntryCard(
            icon: p.isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_rounded,
            color: p.isLowStock ? AppTheme.errorColor : AppTheme.successColor,
            title: p.name,
            subtitle: Row(
              children: [
                if (p.isLowStock) ...[
                  const StatusPill(label: 'স্টক কম', color: AppTheme.errorColor),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    [
                      if (p.buyPrice != null) 'কেনা ৳${formatQty(p.buyPrice!)}',
                      if (p.sellPrice != null) 'বিক্রি ৳${formatQty(p.sellPrice!)}',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            amount: '${formatQty(p.stockQty)} ${p.unit}',
            amountColor: p.isLowStock ? AppTheme.errorColor : Colors.white,
            onTap: () => showAppPanel(context, _ProductStockPanel(productId: p.id)),
          ),
      ],
    );
  }
}

/// One product: stock, quick actions and its stock-in / correction history.
class _ProductStockPanel extends ConsumerWidget {
  final String productId;

  const _ProductStockPanel({required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(stockProductsProvider).where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      return const AppPanelFrame(title: 'স্টক', subtitle: '', child: SizedBox.shrink());
    }
    final entries = ref.watch(stockEntriesProvider(productId));
    final isOwner = ref.watch(currentUserProvider).valueOrNull?.isOwner ?? false;

    return AppPanelFrame(
      title: product.name,
      subtitle: 'স্টকে আছে ${formatQty(product.stockQty)} ${product.unit}'
          '${product.lowStockAt != null ? ' · সতর্কতা ${formatQty(product.lowStockAt!)}' : ''}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => showStockInForm(context, product: product),
                icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
                label: const Text('মাল এসেছে'),
              ),
              OutlinedButton.icon(
                onPressed: () => showStockCountForm(context, product),
                icon: const Icon(Icons.fact_check_rounded, size: 18),
                label: const Text('গুনে ঠিক করুন'),
              ),
              if (isOwner)
                OutlinedButton.icon(
                  onPressed: () => showStockProductForm(context, product: product),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('দাম ও একক'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('স্টক আসা ও ঠিক করার হিসাব', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          const Text(
            'বিক্রিতে কমা স্টক বিক্রির তালিকায় দেখা যাবে',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const Divider(height: 20),
          Flexible(
            child: entries.when(
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('এখনো কিছু নেই', textAlign: TextAlign.center),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _EntryRow(
                        entry: list[i],
                        unit: product.unit,
                        onDelete: isOwner ? () => _confirmDelete(context, ref, list[i]) : null,
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('লোড করা যায়নি: $e'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, StockEntryModel entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('এন্ট্রি মুছবেন?'),
        content: Text('স্টক থেকে ${formatQty(entry.quantity)} ফিরিয়ে নেওয়া হবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('না')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(productsRepositoryProvider)?.deleteStockEntry(entry);
  }
}

class _EntryRow extends StatelessWidget {
  final StockEntryModel entry;
  final String unit;
  final VoidCallback? onDelete;

  const _EntryRow({required this.entry, required this.unit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final up = entry.quantity >= 0;
    final parts = entry.date.split('-');
    final date = parts.length == 3 ? '${int.parse(parts[2])}/${int.parse(parts[1])}' : entry.date;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(date, style: AppTheme.numeric(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.isAdjustment ? 'গুনে ঠিক করা' : 'মাল এসেছে'),
                if ((entry.note ?? '').isNotEmpty || entry.buyPrice != null)
                  Text(
                    [
                      if (entry.buyPrice != null) 'কেনা ৳${formatQty(entry.buyPrice!)}',
                      if ((entry.note ?? '').isNotEmpty) entry.note!,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            '${up ? '+' : '−'}${formatQty(entry.quantity.abs())} $unit',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: up ? AppTheme.successColor : AppTheme.errorColor,
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'মুছুন',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }
}
