import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/localization/strings.dart';
import '../../../widgets/donut_chart.dart';
import '../../reports/report_share_sheet.dart';
import '../../../widgets/widgets.dart';

/// Selected month provider
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Monthly data provider
final monthlyDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final shop = ref.watch(currentShopProvider).value;
  if (shop == null) return {};

  final salesRepo = ref.watch(salesRepositoryProvider);
  final expensesRepo = ref.watch(expensesRepositoryProvider);
  final creditRepo = ref.watch(creditRepositoryProvider);

  if (salesRepo == null || expensesRepo == null || creditRepo == null) {
    return {};
  }

  // Get date range for the month
  final startDate = formatDateForQuery(selectedMonth);
  final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
  final endDate = formatDateForQuery(lastDay);
  final daysInMonth = lastDay.day;

  // Sales and credit totals come from aggregate queries (a few reads instead of
  // one per document); the document reads remain as the offline/no-index fallback.
  Map<String, double> salesTotals;
  try {
    salesTotals = await salesRepo.getRangeTotals(startDate, endDate);
  } catch (_) {
    final sales = await salesRepo.getSalesByDateRange(startDate, endDate);
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
    salesTotals = {
      'totalSales': totalSales,
      'totalProfit': totalProfit,
      'cashSales': cashSales,
      'nonCashSales': nonCashSales,
      'salesCount': sales.length.toDouble(),
    };
  }
  final expenses = await expensesRepo.getExpensesByDateRange(
    startDate,
    endDate,
  );
  Map<String, double> creditSummary;
  try {
    creditSummary = await creditRepo.getCreditSummaryAggregate();
  } catch (_) {
    creditSummary = await creditRepo.getCreditSummary();
  }
  final savingsIds = {
    for (final c in await ref.watch(expenseCategoriesProvider.future))
      if (c.isSavings) c.id,
  };

  final totalSales = salesTotals['totalSales']!;
  final totalProfit = salesTotals['totalProfit']!;
  final cashSales = salesTotals['cashSales']!;
  final nonCashSales = salesTotals['nonCashSales']!;

  double totalExpenses = 0;
  double cashExpenses = 0;
  double nonCashExpenses = 0;
  double totalSavings = 0;
  double cashSavings = 0;
  int expensesCount = 0;
  Map<String, double> expensesByCategory = {};
  Map<String, double> savingsByCategory = {};

  for (final expense in expenses) {
    if (savingsIds.contains(expense.categoryId)) {
      totalSavings += expense.amount;
      if (expense.isCash) cashSavings += expense.amount;
      savingsByCategory[expense.categoryName] =
          (savingsByCategory[expense.categoryName] ?? 0) + expense.amount;
      continue;
    }
    expensesCount++;
    totalExpenses += expense.amount;
    if (expense.isCash) {
      cashExpenses += expense.amount;
    } else {
      nonCashExpenses += expense.amount;
    }
    // Group by category
    final catName = expense.categoryName;
    expensesByCategory[catName] =
        (expensesByCategory[catName] ?? 0) + expense.amount;
  }

  // Calculate averages and other metrics
  final avgDailySales = daysInMonth > 0 ? totalSales / daysInMonth : 0.0;
  // Savings paid from the drawer still leave it, so they count against cash flow.
  final netCashflow = cashSales - cashExpenses - cashSavings;

  return {
    'totalSales': totalSales,
    'totalProfit': totalProfit,
    'cashSales': cashSales,
    'nonCashSales': nonCashSales,
    'totalExpenses': totalExpenses,
    'cashExpenses': cashExpenses,
    'nonCashExpenses': nonCashExpenses,
    'expensesByCategory': expensesByCategory,
    'totalSavings': totalSavings,
    'savingsByCategory': savingsByCategory,
    'avgDailySales': avgDailySales,
    'totalCredit': creditSummary['totalCredit'] ?? 0,
    'totalCollected': creditSummary['totalCollected'] ?? 0,
    'remainingCredit': creditSummary['remaining'] ?? 0,
    'netCashflow': netCashflow,
    'salesCount': salesTotals['salesCount']!.toInt(),
    'expensesCount': expensesCount,
  };
});

class MonthlySummaryScreen extends ConsumerWidget {
  const MonthlySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthlyData = ref.watch(monthlyDataProvider);
    final locale = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(locale, 'monthly_summary_title')),
        actions: [
          if (monthlyData.valueOrNull?.isNotEmpty ?? false)
            IconButton(
              tooltip: tr(locale, 'share_report'),
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => showReportShareSheet(
                context,
                _monthlyReport(ref, locale, selectedMonth, monthlyData.value!),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    ref.read(selectedMonthProvider.notifier).state = DateTime(
                      selectedMonth.year,
                      selectedMonth.month - 1,
                      1,
                    );
                  },
                ),
                InkWell(
                  onTap: () => _selectMonth(context, ref),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatMonth(selectedMonth),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    final now = DateTime.now();
                    final nextMonth = DateTime(
                      selectedMonth.year,
                      selectedMonth.month + 1,
                      1,
                    );
                    if (nextMonth.isBefore(
                      DateTime(now.year, now.month + 1, 1),
                    )) {
                      ref.read(selectedMonthProvider.notifier).state =
                          nextMonth;
                    }
                  },
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: monthlyData.when(
              data: (data) {
                if (data.isEmpty) {
                  return const EmptyState(
                    icon: Icons.analytics_outlined,
                    title: 'ডেটা নেই',
                    message: 'এই মাসের কোনো ডেটা পাওয়া যায়নি',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(monthlyDataProvider);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sales Overview
                        _SummaryCard(
                          title: 'বিক্রয় সামারি',
                          icon: Icons.trending_up,
                          color: AppTheme.successColor,
                          items: [
                            _SummaryItem(
                              'মোট বিক্রয়',
                              CurrencyFormatter.formatNoDecimal(
                                data['totalSales'] ?? 0,
                              ),
                            ),
                            _SummaryItem(
                              'মোট লাভ',
                              CurrencyFormatter.formatNoDecimal(
                                data['totalProfit'] ?? 0,
                              ),
                            ),
                            _SummaryItem(
                              'নগদ বিক্রয়',
                              CurrencyFormatter.formatNoDecimal(
                                data['cashSales'] ?? 0,
                              ),
                            ),
                            _SummaryItem(
                              'ডিজিটাল পেমেন্ট',
                              CurrencyFormatter.formatNoDecimal(
                                data['nonCashSales'] ?? 0,
                              ),
                            ),
                            _SummaryItem(
                              'দৈনিক গড়',
                              CurrencyFormatter.formatNoDecimal(
                                data['avgDailySales'] ?? 0,
                              ),
                            ),
                            _SummaryItem(
                              'বিক্রয় সংখ্যা',
                              '${data['salesCount'] ?? 0}টি',
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Expenses Overview
                        _SummaryCard(
                          title: 'খরচ সামারি',
                          icon: Icons.trending_down,
                          color: AppTheme.errorColor,
                          items: [
                            _SummaryItem(
                              'মোট খরচ',
                              CurrencyFormatter.formatNoDecimal(
                                data['totalExpenses'] ?? 0,
                              ),
                            ),
                            _SummaryItem(
                              'ক্যাশ থেকে খরচ',
                              CurrencyFormatter.formatNoDecimal(
                                data['cashExpenses'] ?? 0,
                              ),
                            ),
                            _SummaryItem(
                              'ক্যাশের বাইরের খরচ',
                              CurrencyFormatter.formatNoDecimal(
                                data['nonCashExpenses'] ?? 0,
                              ),
                            ),
                            _SummaryItem(
                              'খরচ সংখ্যা',
                              '${data['expensesCount'] ?? 0}টি',
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Expense Breakdown by Category
                        if ((data['expensesByCategory'] as Map<String, double>?)
                                ?.isNotEmpty ==
                            true)
                          _ExpenseBreakdownCard(
                            expensesByCategory:
                                data['expensesByCategory']
                                    as Map<String, double>,
                          ),

                        if (((data['totalSavings'] as num?) ?? 0) > 0) ...[
                          const SizedBox(height: 16),
                          _SummaryCard(
                            title: tr(locale, 'savings'),
                            icon: Icons.savings_rounded,
                            color: AppTheme.successColor,
                            items: [
                              _SummaryItem(
                                tr(locale, 'total_savings'),
                                CurrencyFormatter.formatNoDecimal(data['totalSavings']),
                              ),
                              if ((data['savingsByCategory'] as Map<String, double>).length > 1)
                                for (final e in (data['savingsByCategory'] as Map<String, double>).entries)
                                  _SummaryItem(e.key, CurrencyFormatter.formatNoDecimal(e.value)),
                              _SummaryItem(tr(locale, 'savings_not_expense'), ''),
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Credit Summary
                        _SummaryCard(
                          title: 'বাকি সামারি',
                          icon: Icons.credit_card,
                          color: AppTheme.warningColor,
                          items: [
                            _SummaryItem(
                              'মোট বাকি',
                              CurrencyFormatter.formatNoDecimal(
                                data['totalCredit'] ?? 0,
                              ),
                            ),
                            _SummaryItem(
                              'আদায়',
                              CurrencyFormatter.formatNoDecimal(
                                data['totalCollected'] ?? 0,
                              ),
                            ),
                            _SummaryItem(
                              'বকেয়া',
                              CurrencyFormatter.formatNoDecimal(
                                data['remainingCredit'] ?? 0,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Net Cashflow
                        _NetCashflowCard(
                          netCashflow: data['netCashflow'] ?? 0,
                          totalSales: data['totalSales'] ?? 0,
                          totalExpenses: data['totalExpenses'] ?? 0,
                          totalSavings: data['totalSavings'] ?? 0,
                          totalProfit: data['totalProfit'] ?? 0,
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('ডেটা লোড করতে সমস্যা হয়েছে')),
            ),
          ),
        ],
      ),
    );
  }

  ReportData _monthlyReport(
    WidgetRef ref,
    Locale locale,
    DateTime month,
    Map<String, dynamic> data,
  ) {
    String t(String key) => tr(locale, key);
    String money(String key) =>
        CurrencyFormatter.formatNoDecimal((data[key] as num?)?.toDouble() ?? 0);
    final netCashflow = (data['netCashflow'] as num?)?.toDouble() ?? 0;

    return ReportData(
      title: t('monthly_report'),
      period: _formatMonth(month),
      shopName: ref.read(currentShopProvider).valueOrNull?.name ?? '',
      fileName: 'report-${formatDateForQuery(month).substring(0, 7)}.png',
      lines: [
        ReportLine(t('total_sales'), money('totalSales'), color: AppTheme.successColor),
        ReportLine(t('cash_sales'), money('cashSales')),
        ReportLine(t('digital'), money('nonCashSales'), color: AppTheme.infoColor),
        ReportLine(t('daily_avg'), money('avgDailySales')),
        ReportLine(t('report_sales_count'), '${data['salesCount'] ?? 0}'),
        ReportLine(t('profit'), money('totalProfit'), color: AppTheme.violetColor),
        ReportLine(t('report_expenses'), money('totalExpenses'), color: AppTheme.errorColor),
        ReportLine(t('report_cash_expenses'), money('cashExpenses')),
        if (((data['totalSavings'] as num?) ?? 0) > 0)
          ReportLine(t('savings'), money('totalSavings'), color: AppTheme.successColor),
        ReportLine(t('report_credit_due'), money('remainingCredit'), color: AppTheme.warningColor),
      ],
      highlight: ReportLine(
        t('report_net_cash'),
        '${netCashflow < 0 ? '−' : ''}${CurrencyFormatter.formatNoDecimal(netCashflow.abs())}',
      ),
    );
  }

  String _formatMonth(DateTime date) {
    final bengaliMonths = [
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
    ];
    return '${bengaliMonths[date.month - 1]} ${date.year}';
  }

  Future<void> _selectMonth(BuildContext context, WidgetRef ref) async {
    final selectedMonth = ref.read(selectedMonthProvider);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month + 1, 0),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      ref.read(selectedMonthProvider.notifier).state = DateTime(
        picked.year,
        picked.month,
        1,
      );
    }
  }
}

class _SummaryItem {
  final String label;
  final String value;
  _SummaryItem(this.label, this.value);
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_SummaryItem> items;

  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    Text(
                      item.value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseBreakdownCard extends StatelessWidget {
  final Map<String, double> expensesByCategory;

  const _ExpenseBreakdownCard({required this.expensesByCategory});

  @override
  Widget build(BuildContext context) {
    final sorted = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (sum, e) => sum + e.value);
    final maxSlices = chartPalette.length;
    final slices = <(String, double, Color)>[
      for (final (i, e) in sorted.take(maxSlices - 1).indexed) (e.key, e.value, chartPalette[i]),
      if (sorted.length >= maxSlices)
        (
          'অন্যান্য',
          sorted.skip(maxSlices - 1).fold<double>(0, (sum, e) => sum + e.value),
          chartPalette.last,
        ),
    ];

    final donut = DonutChart(
      segments: [for (final s in slices) (s.$2, s.$3)],
      size: 140,
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('মোট', style: Theme.of(context).textTheme.bodySmall),
          FittedBox(
            child: Text(
              CurrencyFormatter.formatCompact(total),
              style: AppTheme.numeric(fontSize: 17),
            ),
          ),
        ],
      ),
    );

    final legend = Column(
      children: [
        for (final (name, value, color) in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${total <= 0 ? 0 : (value / total * 100).round()}%',
                  style: AppTheme.numeric(fontSize: 12, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  CurrencyFormatter.formatNoDecimal(value),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pie_chart,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'ক্যাটাগরি অনুযায়ী খরচ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 420
                  ? Column(children: [donut, const SizedBox(height: 16), legend])
                  : Row(
                      children: [
                        donut,
                        const SizedBox(width: 24),
                        Expanded(child: legend),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetCashflowCard extends StatelessWidget {
  final double netCashflow;
  final double totalSales;
  final double totalExpenses;
  final double totalSavings;
  final double totalProfit;

  const _NetCashflowCard({
    required this.netCashflow,
    required this.totalSales,
    required this.totalExpenses,
    required this.totalSavings,
    required this.totalProfit,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = netCashflow >= 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: isPositive
              ? AppTheme.successGradient
              : AppTheme.errorGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'নেট ক্যাশফ্লো',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              CurrencyFormatter.formatNoDecimal(netCashflow.abs()),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPositive ? 'লাভ হয়েছে' : 'লস হয়েছে',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStat(
                    'বিক্রয়',
                    CurrencyFormatter.formatCompact(totalSales),
                  ),
                  _MiniStat(
                    'খরচ',
                    CurrencyFormatter.formatCompact(totalExpenses),
                  ),
                  if (totalSavings > 0)
                    _MiniStat(
                      'সঞ্চয়',
                      CurrencyFormatter.formatCompact(totalSavings),
                    ),
                  _MiniStat(
                    'লাভ',
                    CurrencyFormatter.formatCompact(totalProfit),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
