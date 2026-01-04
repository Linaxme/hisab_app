import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/dashboard_preferences_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/localization/strings.dart';
import '../../../widgets/modern_widgets.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../widgets/sync_indicator.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final currentShop = ref.watch(currentShopProvider);
    final locale = ref.watch(languageProvider);

    return Scaffold(
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return Center(child: Text(tr(locale, 'user_not_found')));
          }
          return currentShop.when(
            data: (shop) {
              if (shop == null) {
                return Center(child: Text(tr(locale, 'shop_not_found')));
              }
              return _DashboardContent(
                userName: user.name,
                shopName: shop.name,
                isOwner: user.isOwner,
                showProfit: shop.showProfit && user.isOwner,
              );
            },
            loading: () => const DashboardSkeletonLoader(),
            error: (_, __) =>
                Center(child: Text(tr(locale, 'error_loading_shop'))),
          );
        },
        loading: () => const DashboardSkeletonLoader(),
        error: (_, __) => Center(child: Text(tr(locale, 'error_loading_user'))),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final String userName;
  final String shopName;
  final bool isOwner;
  final bool showProfit;

  const _DashboardContent({
    required this.userName,
    required this.shopName,
    required this.isOwner,
    required this.showProfit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dashboardPrefs = ref.watch(dashboardPreferencesProvider);
    final locale = ref.watch(languageProvider);

    // Watch all real data providers
    final salesTotalsAsync = ref.watch(salesTotalsProvider);
    final expensesTotalsAsync = ref.watch(expensesTotalsProvider);
    final depositsTotalAsync = ref.watch(depositsTotalProvider);
    final returnsTotalAsync = ref.watch(returnsTotalProvider);
    final openingCashAsync = ref.watch(openingCashProvider);
    final liveCashAsync = ref.watch(liveCashProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          // Refresh all data
          ref.invalidate(salesTotalsProvider);
          ref.invalidate(expensesTotalsProvider);
          ref.invalidate(depositsTotalProvider);
          ref.invalidate(returnsTotalProvider);
          ref.invalidate(openingCashProvider);
          ref.invalidate(liveCashProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Compact and Professional
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.25)
                      : Colors.blue.withValues(alpha: 0.12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(locale, 'welcome'),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const SyncIndicator(),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkCard
                                : AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.2,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.store_rounded,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                shopName,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),

              const SizedBox(height: 12),

              // Date Selector - Slim Pill Style
              _DateSelector(),

              const SizedBox(height: 12),

              // Live Cash - Hero Card
              liveCashAsync
                  .when(
                    data: (liveCash) => HeroKpiCard(
                      title: tr(locale, 'live_cash'),
                      value: CurrencyFormatter.formatNoDecimal(liveCash),
                      icon: Icons.monetization_on_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    loading: () => HeroKpiCard(
                      title: tr(locale, 'live_cash'),
                      value: '...',
                      icon: Icons.monetization_on_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    error: (_, __) => HeroKpiCard(
                      title: tr(locale, 'live_cash'),
                      value: '৳০',
                      icon: Icons.monetization_on_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 100.ms)
                  .slideY(begin: 0.1),

              const SizedBox(height: 16),

              // KPI Cards - Compact Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 3.0, // Very compact horizontal
                children: [
                  // Opening Cash - Editable
                  if (dashboardPrefs.showOpeningCash)
                    GestureDetector(
                      onTap: () => _showOpeningCashDialog(context, ref),
                      child: openingCashAsync.when(
                        data: (openingCash) => MinimalKpiCard(
                          title: tr(locale, 'opening_cash'),
                          value: CurrencyFormatter.formatNoDecimal(
                            openingCash?.amount ?? 0,
                          ),
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: AppTheme.primaryColor,
                          isCompact: true,
                        ),
                        loading: () => MinimalKpiCard(
                          title: tr(locale, 'opening_cash'),
                          value: '...',
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: AppTheme.primaryColor,
                          isCompact: true,
                        ),
                        error: (_, __) => MinimalKpiCard(
                          title: tr(locale, 'opening_cash'),
                          value: '৳০',
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: AppTheme.primaryColor,
                          isCompact: true,
                        ),
                      ),
                    ).animate().fadeIn(delay: 150.ms),

                  // Today's Sales
                  if (dashboardPrefs.showTodaySales)
                    salesTotalsAsync
                        .when(
                          data: (totals) => MinimalKpiCard(
                            title: tr(locale, 'today_sales'),
                            value: CurrencyFormatter.formatNoDecimal(
                              totals['totalSales'] ?? 0,
                            ),
                            icon: Icons.trending_up_rounded,
                            iconColor: AppTheme.successColor,
                            valueColor: AppTheme.successColor,
                            isCompact: true,
                          ),
                          loading: () => MinimalKpiCard(
                            title: tr(locale, 'today_sales'),
                            value: '...',
                            icon: Icons.trending_up_rounded,
                            iconColor: AppTheme.successColor,
                            isCompact: true,
                          ),
                          error: (_, __) => MinimalKpiCard(
                            title: tr(locale, 'today_sales'),
                            value: '৳০',
                            icon: Icons.trending_up_rounded,
                            iconColor: AppTheme.successColor,
                            isCompact: true,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 200.ms),

                  // Today's Expenses
                  if (dashboardPrefs.showTodayExpenses)
                    expensesTotalsAsync
                        .when(
                          data: (totals) => MinimalKpiCard(
                            title: tr(locale, 'today_expenses'),
                            value: CurrencyFormatter.formatNoDecimal(
                              totals['totalExpenses'] ?? 0,
                            ),
                            icon: Icons.trending_down_rounded,
                            iconColor: AppTheme.errorColor,
                            valueColor: AppTheme.errorColor,
                            isCompact: true,
                          ),
                          loading: () => MinimalKpiCard(
                            title: tr(locale, 'today_expenses'),
                            value: '...',
                            icon: Icons.trending_down_rounded,
                            iconColor: AppTheme.errorColor,
                            isCompact: true,
                          ),
                          error: (_, __) => MinimalKpiCard(
                            title: tr(locale, 'today_expenses'),
                            value: '৳০',
                            icon: Icons.trending_down_rounded,
                            iconColor: AppTheme.errorColor,
                            isCompact: true,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 250.ms),

                  // Profit card (only for owner if enabled)
                  if (showProfit)
                    salesTotalsAsync
                        .when(
                          data: (totals) => MinimalKpiCard(
                            title: tr(locale, 'today_profit'),
                            value: CurrencyFormatter.formatNoDecimal(
                              totals['totalProfit'] ?? 0,
                            ),
                            icon: Icons.assessment_rounded,
                            iconColor: AppTheme.primaryColor,
                            valueColor: Colors.purple,
                            isCompact: true,
                          ),
                          loading: () => MinimalKpiCard(
                            title: tr(locale, 'today_profit'),
                            value: '...',
                            icon: Icons.assessment_rounded,
                            iconColor: AppTheme.primaryColor,
                            isCompact: true,
                          ),
                          error: (_, __) => MinimalKpiCard(
                            title: tr(locale, 'today_profit'),
                            value: '৳০',
                            icon: Icons.assessment_rounded,
                            iconColor: AppTheme.primaryColor,
                            isCompact: true,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 300.ms),
                ],
              ),

              const SizedBox(height: 16),

              // Quick Actions - Clean List Style
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr(locale, 'quick_actions'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 10),
              QuickActionTile(
                label: tr(locale, 'add_sale'),
                icon: Icons.add_shopping_cart_rounded,
                color: AppTheme.primaryColor,
                onTap: () => context.go('/sales'),
              ).animate().fadeIn(delay: 400.ms),
              QuickActionTile(
                label: tr(locale, 'add_expense'),
                icon: Icons.receipt_long_rounded,
                color: AppTheme.errorColor,
                onTap: () => context.go('/expenses'),
              ).animate().fadeIn(delay: 450.ms),
              QuickActionTile(
                label: tr(locale, 'add_deposit'),
                icon: Icons.savings_rounded,
                color: AppTheme.successColor,
                onTap: () => context.go('/deposits'),
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 16),

              // Today's Summary
              SectionHeader(
                title: tr(locale, 'today_summary'),
              ).animate().fadeIn(delay: 700.ms),
              const SizedBox(height: 10),
              ModernCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    salesTotalsAsync.when(
                      data: (totals) => SummaryRow(
                        label: tr(locale, 'cash_sales'),
                        value: CurrencyFormatter.formatNoDecimal(
                          totals['cashSales'] ?? 0,
                        ),
                        valueColor: AppTheme.successColor,
                      ),
                      loading: () => SummaryRow(
                        label: tr(locale, 'cash_sales'),
                        value: '...',
                      ),
                      error: (_, __) => SummaryRow(
                        label: tr(locale, 'cash_sales'),
                        value: '৳০',
                      ),
                    ),
                    const Divider(height: 1),
                    salesTotalsAsync.when(
                      data: (totals) => SummaryRow(
                        label: tr(locale, 'non_cash_sales'),
                        value: CurrencyFormatter.formatNoDecimal(
                          totals['nonCashSales'] ?? 0,
                        ),
                      ),
                      loading: () => SummaryRow(
                        label: tr(locale, 'non_cash_sales'),
                        value: '...',
                      ),
                      error: (_, __) => SummaryRow(
                        label: tr(locale, 'non_cash_sales'),
                        value: '৳০',
                      ),
                    ),
                    const Divider(height: 1),
                    expensesTotalsAsync.when(
                      data: (totals) => SummaryRow(
                        label: tr(locale, 'cash_expenses'),
                        value: CurrencyFormatter.formatNoDecimal(
                          totals['cashExpenses'] ?? 0,
                        ),
                        valueColor: AppTheme.errorColor,
                      ),
                      loading: () => SummaryRow(
                        label: tr(locale, 'cash_expenses'),
                        value: '...',
                      ),
                      error: (_, __) => SummaryRow(
                        label: tr(locale, 'cash_expenses'),
                        value: '৳০',
                      ),
                    ),
                    if (dashboardPrefs.showDeposits) ...[
                      const Divider(height: 1),
                      depositsTotalAsync.when(
                        data: (total) => SummaryRow(
                          label: tr(locale, 'deposit'),
                          value: CurrencyFormatter.formatNoDecimal(total),
                          valueColor: AppTheme.primaryColor,
                        ),
                        loading: () => SummaryRow(
                          label: tr(locale, 'deposit'),
                          value: '...',
                        ),
                        error: (_, __) => SummaryRow(
                          label: tr(locale, 'deposit'),
                          value: '৳০',
                        ),
                      ),
                    ],
                    if (dashboardPrefs.showReturns) ...[
                      const Divider(height: 1),
                      returnsTotalAsync.when(
                        data: (total) => SummaryRow(
                          label: tr(locale, 'return'),
                          value: CurrencyFormatter.formatNoDecimal(total),
                          valueColor: AppTheme.warningColor,
                        ),
                        loading: () => SummaryRow(
                          label: tr(locale, 'return'),
                          value: '...',
                        ),
                        error: (_, __) => SummaryRow(
                          label: tr(locale, 'return'),
                          value: '৳০',
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 750.ms).slideY(begin: 0.2),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showOpeningCashDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final openingCash = ref.read(openingCashProvider).value;
    final locale = ref.read(languageProvider);
    if (openingCash != null) {
      controller.text = openingCash.amount.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr(locale, 'opening_cash_dialog_title')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr(locale, 'amount'),
            prefixText: '৳ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(locale, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              final repository = ref.read(openingCashRepositoryProvider);
              final selectedDate = ref.read(selectedDateProvider);

              if (repository != null) {
                final dateStr = formatDateForQuery(selectedDate);
                final currentUser = ref.read(currentUserProvider).value;
                await repository.setOpeningCash(
                  dateStr,
                  amount,
                  currentUser?.uid ?? '',
                );
                ref.invalidate(openingCashProvider);
                ref.invalidate(liveCashProvider);
              }

              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text(
              tr(locale, 'save'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSelector extends ConsumerWidget {
  String _formatDateInBengali(DateTime date, Locale locale) {
    final isBangla = locale.languageCode == 'bn';
    final weekdays = isBangla
        ? [
            'সোমবার',
            'মঙ্গলবার',
            'বুধবার',
            'বৃহস্পতিবার',
            'শুক্রবার',
            'শনিবার',
            'রবিবার',
          ]
        : [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];
    final months = isBangla
        ? [
            'জানুয়ারি',
            'ফেব্রুয়ারি',
            'মার্চ',
            'এপ্রিল',
            'মে',
            'জুন',
            'জুলাই',
            'আগস্ট',
            'সেপ্টেম্বর',
            'অক্টোবর',
            'নভেম্বর',
            'ডিসেম্বর',
          ]
        : [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];

    return '$weekday ${date.day} $month ${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final locale = ref.watch(languageProvider);
    final today = DateTime.now();
    final isToday =
        selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(50), // Pill shape
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDateInBengali(selectedDate, locale),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tr(locale, 'today'),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  ref.read(selectedDateProvider.notifier).state = selectedDate
                      .subtract(const Duration(days: 1));
                },
                tooltip: 'আগের দিন',
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: isToday
                    ? null
                    : () {
                        ref.read(selectedDateProvider.notifier).state =
                            selectedDate.add(const Duration(days: 1));
                      },
                tooltip: 'পরের দিন',
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showDatePicker(context, ref, selectedDate),
                tooltip: 'তারিখ নির্বাচন',
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker(
    BuildContext context,
    WidgetRef ref,
    DateTime currentDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }
}
