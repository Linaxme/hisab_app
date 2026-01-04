import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dashboard Card Visibility Preferences
class DashboardPreferences {
  final bool showOpeningCash;
  final bool showTodaySales;
  final bool showTodayExpenses;
  final bool showDeposits;
  final bool showReturns;

  DashboardPreferences({
    this.showOpeningCash = true,
    this.showTodaySales = true,
    this.showTodayExpenses = true,
    this.showDeposits = true,
    this.showReturns = true,
  });

  DashboardPreferences copyWith({
    bool? showOpeningCash,
    bool? showTodaySales,
    bool? showTodayExpenses,
    bool? showDeposits,
    bool? showReturns,
  }) {
    return DashboardPreferences(
      showOpeningCash: showOpeningCash ?? this.showOpeningCash,
      showTodaySales: showTodaySales ?? this.showTodaySales,
      showTodayExpenses: showTodayExpenses ?? this.showTodayExpenses,
      showDeposits: showDeposits ?? this.showDeposits,
      showReturns: showReturns ?? this.showReturns,
    );
  }
}

/// Dashboard Preferences Notifier
class DashboardPreferencesNotifier extends StateNotifier<DashboardPreferences> {
  final SharedPreferences _prefs;

  DashboardPreferencesNotifier(this._prefs)
      : super(DashboardPreferences(
          showOpeningCash: _prefs.getBool('show_opening_cash') ?? true,
          showTodaySales: _prefs.getBool('show_today_sales') ?? true,
          showTodayExpenses: _prefs.getBool('show_today_expenses') ?? true,
          showDeposits: _prefs.getBool('show_deposits') ?? true,
          showReturns: _prefs.getBool('show_returns') ?? true,
        ));

  Future<void> setOpeningCashVisibility(bool value) async {
    await _prefs.setBool('show_opening_cash', value);
    state = state.copyWith(showOpeningCash: value);
  }

  Future<void> setTodaySalesVisibility(bool value) async {
    await _prefs.setBool('show_today_sales', value);
    state = state.copyWith(showTodaySales: value);
  }

  Future<void> setTodayExpensesVisibility(bool value) async {
    await _prefs.setBool('show_today_expenses', value);
    state = state.copyWith(showTodayExpenses: value);
  }

  Future<void> setDepositsVisibility(bool value) async {
    await _prefs.setBool('show_deposits', value);
    state = state.copyWith(showDeposits: value);
  }

  Future<void> setReturnsVisibility(bool value) async {
    await _prefs.setBool('show_returns', value);
    state = state.copyWith(showReturns: value);
  }
}

/// Provider for SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden');
});

/// Provider for Dashboard Preferences
final dashboardPreferencesProvider =
    StateNotifierProvider<DashboardPreferencesNotifier, DashboardPreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DashboardPreferencesNotifier(prefs);
});
