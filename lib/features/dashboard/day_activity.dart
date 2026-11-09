import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';

enum ActivityKind { sale, expense, creditSale, collection, deposit, returned }

/// One transaction of the selected day, whatever collection it came from.
class ActivityEntry {
  final ActivityKind kind;
  final DateTime time;
  final double amount;

  /// +1 adds to the cash drawer, -1 takes from it, 0 leaves it untouched.
  final int cashEffect;

  /// Raw name/note; the view supplies a fallback when it is empty.
  final String? label;
  final double profit;

  /// The original model, so the entry can be opened for editing.
  final Object source;

  /// An expense in a savings category: still leaves the drawer, but is not spending.
  final bool isSavings;

  const ActivityEntry({
    required this.kind,
    required this.time,
    required this.amount,
    required this.cashEffect,
    required this.source,
    this.label,
    this.profit = 0,
    this.isSavings = false,
  });
}

class DayFlow {
  final double cashIn;
  final double cashOut;
  final double digitalSales;
  final double totalSales;
  final double totalExpenses;
  final double savings;
  final double profit;

  const DayFlow({
    this.cashIn = 0,
    this.cashOut = 0,
    this.digitalSales = 0,
    this.totalSales = 0,
    this.totalExpenses = 0,
    this.savings = 0,
    this.profit = 0,
  });

  double get net => cashIn - cashOut;
}

String? _nonEmpty(String? value) =>
    (value == null || value.trim().isEmpty) ? null : value.trim();

final dayActivityProvider = Provider.autoDispose<AsyncValue<List<ActivityEntry>>>((ref) {
  final sales = ref.watch(salesByDateProvider);
  final expenses = ref.watch(expensesByDateProvider);
  final credits = ref.watch(creditSalesByDateProvider);
  final collections = ref.watch(collectionsByDateProvider);
  final deposits = ref.watch(depositsByDateProvider);
  final returns = ref.watch(returnsByDateProvider);
  final savingsIds = ref.watch(savingsCategoryIdsProvider);

  final sources = <AsyncValue<Object>>[sales, expenses, credits, collections, deposits, returns];
  for (final source in sources) {
    if (source.hasError && !source.hasValue) {
      return AsyncError(source.error!, source.stackTrace ?? StackTrace.current);
    }
  }
  if (sources.any((s) => !s.hasValue)) return const AsyncLoading();

  // Only the day's collections need a customer name, so read just those credit sales.
  final customerById = {
    for (final id in {for (final c in collections.value!) c.creditSaleId})
      id: ref.watch(creditSaleByIdProvider(id)).valueOrNull?.customerName,
  };

  final entries = <ActivityEntry>[
    for (final s in sales.value!)
      ActivityEntry(
        kind: ActivityKind.sale,
        time: s.createdAt,
        amount: s.sellPrice,
        cashEffect: s.isCash ? 1 : 0,
        label: _nonEmpty(s.productName),
        profit: s.profit,
        source: s,
      ),
    for (final e in expenses.value!)
      ActivityEntry(
        kind: ActivityKind.expense,
        time: e.createdAt,
        amount: e.amount,
        cashEffect: e.isCash ? -1 : 0,
        label: _nonEmpty(e.subCategoryName) ?? _nonEmpty(e.categoryName),
        source: e,
        isSavings: savingsIds.contains(e.categoryId),
      ),
    for (final c in credits.value!)
      ActivityEntry(
        kind: ActivityKind.creditSale,
        time: c.createdAt,
        amount: c.amount,
        cashEffect: 0,
        label: _nonEmpty(c.customerName),
        source: c,
      ),
    for (final c in collections.value!)
      ActivityEntry(
        kind: ActivityKind.collection,
        time: c.createdAt,
        amount: c.amount,
        cashEffect: 1,
        label: _nonEmpty(customerById[c.creditSaleId]),
        source: c,
      ),
    // Auto-created deposits only mirror digital sales, which are listed already.
    for (final d in deposits.value!.where((d) => !d.isAutoCreated))
      ActivityEntry(
        kind: ActivityKind.deposit,
        time: d.createdAt,
        amount: d.amount,
        cashEffect: -1,
        label: _nonEmpty(d.note),
        source: d,
      ),
    for (final r in returns.value!)
      ActivityEntry(
        kind: ActivityKind.returned,
        time: r.createdAt,
        amount: r.amount,
        cashEffect: -1,
        label: _nonEmpty(r.note),
        source: r,
      ),
  ]..sort((a, b) => b.time.compareTo(a.time));

  return AsyncData(entries);
});

final dayFlowProvider = Provider.autoDispose<AsyncValue<DayFlow>>((ref) {
  return ref.watch(dayActivityProvider).whenData((entries) {
    double cashIn = 0, cashOut = 0, digital = 0, sales = 0, expenses = 0, savings = 0, profit = 0;
    for (final e in entries) {
      if (e.cashEffect > 0) cashIn += e.amount;
      if (e.cashEffect < 0) cashOut += e.amount;
      switch (e.kind) {
        case ActivityKind.sale:
          sales += e.amount;
          profit += e.profit;
          if (e.cashEffect == 0) digital += e.amount;
        case ActivityKind.expense when e.isSavings:
          savings += e.amount;
        case ActivityKind.expense:
          expenses += e.amount;
        default:
          break;
      }
    }
    return DayFlow(
      cashIn: cashIn,
      cashOut: cashOut,
      digitalSales: digital,
      totalSales: sales,
      totalExpenses: expenses,
      savings: savings,
      profit: profit,
    );
  });
});

/// Live cash recomputed from the same streams as the timeline, so both
/// update together the moment an entry is saved.
final dayLiveCashProvider = Provider.autoDispose<AsyncValue<double>>((ref) {
  final opening = ref.watch(openingCashProvider);
  final flow = ref.watch(dayFlowProvider);
  if (!opening.hasValue || !flow.hasValue) {
    return flow.hasError ? AsyncError(flow.error!, flow.stackTrace!) : const AsyncLoading();
  }
  return AsyncData((opening.value?.amount ?? 0) + flow.value!.net);
});
