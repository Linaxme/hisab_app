import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import 'providers.dart';

/// Accounts that run the app: approve payments and set prices. Keep in sync with
/// `isSuperAdmin()` in firestore.rules.
const superAdminUids = {'NzYKmwMzBHg6k5YU6owjTDbnXVd2'};

final premiumRepositoryProvider = Provider<PremiumRepository>((ref) => PremiumRepository());

final isSuperAdminProvider = Provider<bool>((ref) {
  final uid = ref.watch(currentUserProvider).valueOrNull?.uid;
  return uid != null && superAdminUids.contains(uid);
});

final shopPremiumProvider = StreamProvider<ShopPremiumModel?>((ref) {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return Stream.value(null);
  return ref.watch(premiumRepositoryProvider).watchShopPremium(shopId);
});

final stockAddonActiveProvider = Provider<bool>((ref) {
  return ref.watch(shopPremiumProvider).valueOrNull?.isStockActive ?? false;
});

final premiumConfigProvider = StreamProvider<PremiumConfigModel>((ref) {
  return ref.watch(premiumRepositoryProvider).watchConfig();
});

final myPremiumRequestsProvider = StreamProvider<List<PremiumRequestModel>>((ref) {
  final uid = ref.watch(currentUserProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(premiumRepositoryProvider).watchMyRequests(uid);
});

final pendingPremiumRequestsProvider = StreamProvider<List<PremiumRequestModel>>((ref) {
  if (!ref.watch(isSuperAdminProvider)) return Stream.value([]);
  return ref.watch(premiumRepositoryProvider).watchPendingRequests();
});

final recentPremiumRequestsProvider = StreamProvider<List<PremiumRequestModel>>((ref) {
  if (!ref.watch(isSuperAdminProvider)) return Stream.value([]);
  return ref.watch(premiumRepositoryProvider).watchRecentRequests();
});

// ============ STOCK ============

/// Products whose stock is counted, low stock first, then by name.
final stockProductsProvider = Provider<List<ProductModel>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const <ProductModel>[];
  return products.where((p) => p.trackStock).toList()
    ..sort((a, b) {
      if (a.isLowStock != b.isLowStock) return a.isLowStock ? -1 : 1;
      return a.name.compareTo(b.name);
    });
});

/// Low-stock products, only while the Stock add-on is active.
final lowStockProductsProvider = Provider<List<ProductModel>>((ref) {
  if (!ref.watch(stockAddonActiveProvider)) return const [];
  return ref.watch(stockProductsProvider).where((p) => p.isLowStock).toList();
});

final stockEntriesProvider =
    StreamProvider.autoDispose.family<List<StockEntryModel>, String>((ref, productId) {
  final repository = ref.watch(productsRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchStockEntries(productId);
});
