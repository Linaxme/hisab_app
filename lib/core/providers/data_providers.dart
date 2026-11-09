import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import 'providers.dart';

// Extension for caching providers
extension CacheForExtension on AutoDisposeRef {
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, () => link.close());
    onDispose(() => timer.cancel());
  }
}

// ============ DATE PROVIDER ============
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

String formatDateForQuery(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ============ PRODUCTS PROVIDERS ============
final productsRepositoryProvider = Provider<ProductsRepository?>((ref) {
  final shop = ref.watch(currentShopProvider).value;
  if (shop == null) return null;
  return ProductsRepository(shopId: shop.id);
});

final productsProvider = StreamProvider<List<ProductModel>>((ref) {
  final repository = ref.watch(productsRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchProducts();
});

// ============ SALES PROVIDERS ============
final salesRepositoryProvider = Provider<SalesRepository?>((ref) {
  final shop = ref.watch(currentShopProvider).value;
  if (shop == null) return null;
  return SalesRepository(shopId: shop.id);
});

/// Latest sales total of every day seen live this session, newer than any fetched copy.
final liveDaySalesTotalsProvider = Provider<Map<String, double>>((ref) => {});

final salesByDateProvider = StreamProvider<List<SaleModel>>((ref) {
  final repository = ref.watch(salesRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  
  if (repository == null) return Stream.value([]);
  
  final dateStr = formatDateForQuery(date);
  final liveTotals = ref.read(liveDaySalesTotalsProvider);
  return repository.watchSalesByDate(dateStr).map((sales) {
    liveTotals[dateStr] = sales.fold<double>(0, (sum, s) => sum + s.sellPrice);
    return sales;
  });
});

// Totals are derived from the live streams, so they cost no extra reads.
final salesTotalsProvider = Provider<AsyncValue<Map<String, double>>>((ref) {
  return ref.watch(salesByDateProvider).whenData((sales) {
    double totalSales = 0, totalProfit = 0, cashSales = 0, nonCashSales = 0;
    for (final sale in sales) {
      totalSales += sale.sellPrice;
      totalProfit += sale.profit;
      if (sale.isCash) {
        cashSales += sale.sellPrice;
      } else {
        nonCashSales += sale.sellPrice;
      }
    }
    return {
      'totalSales': totalSales,
      'totalProfit': totalProfit,
      'cashSales': cashSales,
      'nonCashSales': nonCashSales,
    };
  });
});

// ============ EXPENSES PROVIDERS ============
final expensesRepositoryProvider = Provider<ExpensesRepository?>((ref) {
  final shop = ref.watch(currentShopProvider).value;
  if (shop == null) return null;
  return ExpensesRepository(shopId: shop.id);
});

final expensesByDateProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final repository = ref.watch(expensesRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  
  if (repository == null) return Stream.value([]);
  
  return repository.watchExpensesByDate(formatDateForQuery(date));
});

final expensesTotalsProvider = Provider<AsyncValue<Map<String, double>>>((ref) {
  return ref.watch(expensesByDateProvider).whenData((expenses) {
    double totalExpenses = 0, cashExpenses = 0, nonCashExpenses = 0;
    for (final expense in expenses) {
      totalExpenses += expense.amount;
      if (expense.isCash) {
        cashExpenses += expense.amount;
      } else {
        nonCashExpenses += expense.amount;
      }
    }
    return {
      'totalExpenses': totalExpenses,
      'cashExpenses': cashExpenses,
      'nonCashExpenses': nonCashExpenses,
    };
  });
});

final expenseCategoriesProvider = StreamProvider<List<ExpenseCategoryModel>>((ref) {
  final repository = ref.watch(expensesRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchCategories();
});

/// Ids of the categories marked as savings; their expenses stay out of expense totals.
final savingsCategoryIdsProvider = Provider<Set<String>>((ref) {
  final categories = ref.watch(expenseCategoriesProvider).valueOrNull ?? const [];
  return {for (final c in categories) if (c.isSavings) c.id};
});

final expenseSubcategoriesProvider = StreamProvider.family<List<ExpenseSubCategoryModel>, String>((ref, categoryId) {
  final repository = ref.watch(expensesRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchSubcategories(categoryId);
});

// ============ CREDIT PROVIDERS ============
final creditRepositoryProvider = Provider<CreditRepository?>((ref) {
  final shop = ref.watch(currentShopProvider).value;
  if (shop == null) return null;
  return CreditRepository(shopId: shop.id);
});

final creditSalesProvider = StreamProvider<List<CreditSaleModel>>((ref) {
  final repository = ref.watch(creditRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchCreditSales();
});

// Filtered from the all-credits listener instead of opening a second one.
final pendingCreditSalesProvider = Provider<AsyncValue<List<CreditSaleModel>>>((ref) {
  return ref.watch(creditSalesProvider).whenData(
        (sales) => sales.where((s) => !s.isFullyPaid).toList(),
      );
});

/// One credit sale, live; used where only a few are needed (e.g. names in the timeline).
final creditSaleByIdProvider =
    StreamProvider.autoDispose.family<CreditSaleModel?, String>((ref, id) {
  final repository = ref.watch(creditRepositoryProvider);
  if (repository == null) return Stream.value(null);
  return repository.watchCreditSale(id);
});

final creditSalesByDateProvider = StreamProvider<List<CreditSaleModel>>((ref) {
  final repository = ref.watch(creditRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchCreditSalesByDate(formatDateForQuery(date));
});

final collectionsByDateProvider = StreamProvider<List<CreditCollectionModel>>((ref) {
  final repository = ref.watch(creditRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchCollectionsByDate(formatDateForQuery(date));
});

final creditSummaryProvider = Provider<AsyncValue<Map<String, double>>>((ref) {
  return ref.watch(creditSalesProvider).whenData(summarizeCredits);
});

Map<String, double> summarizeCredits(List<CreditSaleModel> creditSales) {
  double totalCredit = 0;
  double totalCollected = 0;
  for (final sale in creditSales) {
    totalCredit += sale.amount;
    totalCollected += sale.collectedAmount;
  }
  return {
    'totalCredit': totalCredit,
    'totalCollected': totalCollected,
    'remaining': totalCredit - totalCollected,
  };
}

// ============ DEPOSITS PROVIDERS ============
final depositsRepositoryProvider = Provider<DepositsRepository?>((ref) {
  final shop = ref.watch(currentShopProvider).value;
  if (shop == null) return null;
  return DepositsRepository(shopId: shop.id);
});

final depositsByDateProvider = StreamProvider<List<DepositModel>>((ref) {
  final repository = ref.watch(depositsRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  
  if (repository == null) return Stream.value([]);
  
  return repository.watchDepositsByDate(formatDateForQuery(date));
});

final depositsTotalProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(depositsByDateProvider).whenData(
        (deposits) => deposits.fold<double>(0.0, (sum, d) => sum + d.amount),
      );
});

// ============ RETURNS PROVIDERS ============
final returnsRepositoryProvider = Provider<ReturnsRepository?>((ref) {
  final shop = ref.watch(currentShopProvider).value;
  if (shop == null) return null;
  return ReturnsRepository(shopId: shop.id);
});

final returnsByDateProvider = StreamProvider<List<ReturnModel>>((ref) {
  final repository = ref.watch(returnsRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  
  if (repository == null) return Stream.value([]);
  
  return repository.watchReturnsByDate(formatDateForQuery(date));
});

final returnsTotalProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(returnsByDateProvider).whenData(
        (returns) => returns.fold<double>(0.0, (sum, r) => sum + r.amount),
      );
});

// ============ OPENING CASH PROVIDERS ============
final openingCashRepositoryProvider = Provider<OpeningCashRepository?>((ref) {
  final shop = ref.watch(currentShopProvider).value;
  if (shop == null) return null;
  return OpeningCashRepository(shopId: shop.id);
});

final openingCashProvider = StreamProvider<OpeningCashModel?>((ref) {
  final repository = ref.watch(openingCashRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  
  if (repository == null) return Stream.value(null);
  
  return repository.watchOpeningCash(formatDateForQuery(date));
});

// ============ LIVE CASH PROVIDER ============
// LiveCash = OpeningCash + CashSales + CreditCollections - ManualDeposits - CashExpenses - Returns
// Note: Auto-created deposits from non-cash sales are excluded
final liveCashProvider = Provider<AsyncValue<double>>((ref) {
  final opening = ref.watch(openingCashProvider);
  final salesTotals = ref.watch(salesTotalsProvider);
  final expensesTotals = ref.watch(expensesTotalsProvider);
  final deposits = ref.watch(depositsByDateProvider);
  final returnsTotal = ref.watch(returnsTotalProvider);
  final collections = ref.watch(collectionsByDateProvider);

  final sources = <AsyncValue<Object?>>[
    opening, salesTotals, expensesTotals, deposits, returnsTotal, collections,
  ];
  for (final source in sources) {
    if (source.hasError && !source.hasValue) {
      return AsyncError(source.error!, source.stackTrace ?? StackTrace.current);
    }
  }
  if (sources.any((s) => !s.hasValue)) return const AsyncLoading();

  final openingCash = opening.value?.amount ?? 0;
  final cashSales = salesTotals.value!['cashSales'] ?? 0;
  final cashExpenses = expensesTotals.value!['cashExpenses'] ?? 0;
  final manualDepositsTotal = deposits.value!
      .where((d) => !d.isAutoCreated)
      .fold<double>(0.0, (sum, d) => sum + d.amount);
  final creditCollections = collections.value!.fold<double>(0.0, (sum, c) => sum + c.amount);

  return AsyncData(openingCash + cashSales + creditCollections - manualDepositsTotal -
      cashExpenses - returnsTotal.value!);
});
