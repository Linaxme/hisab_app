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

final salesByDateProvider = StreamProvider<List<SaleModel>>((ref) {
  final repository = ref.watch(salesRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  
  if (repository == null) return Stream.value([]);
  
  return repository.watchSalesByDate(formatDateForQuery(date));
});

final salesTotalsProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  ref.cacheFor(const Duration(seconds: 30));
  
  final repository = ref.watch(salesRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  
  if (repository == null) {
    return {'totalSales': 0, 'totalProfit': 0, 'cashSales': 0, 'nonCashSales': 0};
  }
  
  return repository.getDayTotals(formatDateForQuery(date));
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

final expensesTotalsProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  ref.cacheFor(const Duration(seconds: 30));
  
  final repository = ref.watch(expensesRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  
  if (repository == null) {
    return {'totalExpenses': 0, 'cashExpenses': 0, 'nonCashExpenses': 0};
  }
  
  return repository.getDayTotals(formatDateForQuery(date));
});

final expenseCategoriesProvider = StreamProvider<List<ExpenseCategoryModel>>((ref) {
  final repository = ref.watch(expensesRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchCategories();
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

final pendingCreditSalesProvider = StreamProvider<List<CreditSaleModel>>((ref) {
  final repository = ref.watch(creditRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchCreditSales(pendingOnly: true);
});

final creditSummaryProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  ref.cacheFor(const Duration(seconds: 30));
  
  final repository = ref.watch(creditRepositoryProvider);
  if (repository == null) {
    return {'totalCredit': 0, 'totalCollected': 0, 'remaining': 0};
  }
  return repository.getCreditSummary();
});

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

final depositsTotalProvider = FutureProvider.autoDispose<double>((ref) async {
  ref.cacheFor(const Duration(seconds: 30));
  
  final repository = ref.watch(depositsRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  
  if (repository == null) return 0;
  
  return repository.getDayTotal(formatDateForQuery(date));
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

final returnsTotalProvider = FutureProvider.autoDispose<double>((ref) async {
  ref.cacheFor(const Duration(seconds: 30));
  
  final repository = ref.watch(returnsRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  
  if (repository == null) return 0;
  
  return repository.getDayTotal(formatDateForQuery(date));
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
final liveCashProvider = FutureProvider.autoDispose<double>((ref) async {
  // Cache for 30 seconds to avoid redundant queries
  ref.cacheFor(const Duration(seconds: 30));
  
  final date = ref.watch(selectedDateProvider);
  final dateStr = formatDateForQuery(date);
  
  final openingCashRepo = ref.watch(openingCashRepositoryProvider);
  final salesRepo = ref.watch(salesRepositoryProvider);
  final expensesRepo = ref.watch(expensesRepositoryProvider);
  final depositsRepo = ref.watch(depositsRepositoryProvider);
  final returnsRepo = ref.watch(returnsRepositoryProvider);
  final creditRepo = ref.watch(creditRepositoryProvider);
  
  if (openingCashRepo == null || salesRepo == null || expensesRepo == null ||
      depositsRepo == null || returnsRepo == null || creditRepo == null) {
    return 0;
  }
  
  // Fetch all data in parallel for better performance
  final results = await Future.wait([
    openingCashRepo.getOpeningCashAmount(dateStr),
    salesRepo.getDayTotals(dateStr),
    expensesRepo.getDayTotals(dateStr),
    depositsRepo.getManualDepositsDayTotal(dateStr),
    returnsRepo.getDayTotal(dateStr),
    creditRepo.getCollectionsByDate(dateStr),
  ]);
  
  final openingCash = results[0] as double;
  final salesTotals = results[1] as Map<String, double>;
  final expensesTotals = results[2] as Map<String, double>;
  final manualDepositsTotal = results[3] as double;
  final returnsTotal = results[4] as double;
  final creditCollections = results[5] as double;
  
  final cashSales = salesTotals['cashSales'] ?? 0;
  final cashExpenses = expensesTotals['cashExpenses'] ?? 0;
  
  return openingCash + cashSales + creditCollections - manualDepositsTotal - cashExpenses - returnsTotal;
});
