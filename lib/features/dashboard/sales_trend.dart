import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/strings.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';

class TrendPoint {
  final DateTime day;
  final double sales;

  const TrendPoint(this.day, this.sales);
}

final trendDaysProvider = StateProvider<int>((ref) => 7);

/// Sales total of one day, fetched once per session.
final daySalesTotalProvider = FutureProvider.family<double, String>((ref, date) async {
  final repository = ref.watch(salesRepositoryProvider);
  if (repository == null) return 0;
  try {
    return await repository.getDaySalesSum(date);
  } catch (_) {
    final sales = await repository.getSalesByDate(date);
    return sales.fold<double>(0, (sum, s) => sum + s.sellPrice);
  }
});

/// Daily sales for the [trendDaysProvider] days ending on the selected date.
/// The selected day comes from its live stream; other days from the session cache.
final salesTrendProvider = FutureProvider.autoDispose<List<TrendPoint>>((ref) async {
  ref.cacheFor(const Duration(minutes: 2));
  final days = ref.watch(trendDaysProvider);
  final selected = ref.watch(selectedDateProvider);
  final selectedTotal = ref.watch(salesByDateProvider.select(
    (v) => v.valueOrNull?.fold<double>(0, (sum, s) => sum + s.sellPrice),
  ));
  final liveTotals = ref.watch(liveDaySalesTotalsProvider);

  final end = DateTime(selected.year, selected.month, selected.day);
  final start = end.subtract(Duration(days: days - 1));
  final dates = [
    for (var i = 0; i < days; i++) formatDateForQuery(start.add(Duration(days: i))),
  ];
  final selectedKey = formatDateForQuery(end);

  final totals = await Future.wait([
    for (final date in dates)
      if (date == selectedKey && selectedTotal != null)
        Future.value(selectedTotal)
      else if (liveTotals.containsKey(date))
        Future.value(liveTotals[date]!)
      else
        ref.watch(daySalesTotalProvider(date).future),
  ]);

  return [
    for (var i = 0; i < days; i++) TrendPoint(start.add(Duration(days: i)), totals[i]),
  ];
});

const _weekdaysBn = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি'];
const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class SalesTrendCard extends ConsumerStatefulWidget {
  const SalesTrendCard({super.key});

  @override
  ConsumerState<SalesTrendCard> createState() => _SalesTrendCardState();
}

class _SalesTrendCardState extends ConsumerState<SalesTrendCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final days = ref.watch(trendDaysProvider);
    final trend = ref.watch(salesTrendProvider);
    String t(String key) => tr(locale, key);
    String money(double v) => CurrencyFormatter.formatNoDecimal(v);
    final isBn = locale.languageCode == 'bn';

    final points = trend.valueOrNull ?? const <TrendPoint>[];
    final total = points.fold<double>(0, (sum, p) => sum + p.sales);
    final best = points.isEmpty ? null : points.reduce((a, b) => b.sales > a.sales ? b : a);
    final selected = (_selected != null && _selected! < points.length) ? points[_selected!] : null;

    String dayLabel(DateTime d) =>
        days == 7 ? (isBn ? _weekdaysBn : _weekdaysEn)[d.weekday - 1] : '${d.day}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(t('sales_trend'), style: Theme.of(context).textTheme.titleMedium)),
              _RangeToggle(
                value: days,
                labels: {7: t('days_7'), 30: t('days_30')},
                onChanged: (v) {
                  setState(() => _selected = null);
                  ref.read(trendDaysProvider.notifier).state = v;
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TrendStat(label: t('trend_total'), value: money(total), color: AppTheme.primaryColor),
              _TrendStat(label: t('daily_avg'), value: money(points.isEmpty ? 0 : total / points.length)),
              _TrendStat(
                label: t('best_day'),
                value: best == null || best.sales <= 0 ? '—' : '${best.day.day}/${best.day.month}',
                color: AppTheme.goldColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                selected == null
                    ? ''
                    : '${selected.day.day}/${selected.day.month} · ${money(selected.sales)}',
                key: ValueKey(_selected),
                style: AppTheme.numeric(fontSize: 13, color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 140,
            child: trend.isLoading && points.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _Bars(
                    points: points,
                    selected: _selected,
                    gap: days == 7 ? 10 : 3,
                    onSelect: (i) => setState(() => _selected = _selected == i ? null : i),
                  ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (i, p) in points.indexed)
                Expanded(
                  child: Text(
                    days == 7 || i % 5 == 0 || i == points.length - 1 ? dayLabel(p.day) : '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: i == _selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                      fontWeight: i == _selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  final List<TrendPoint> points;
  final int? selected;
  final double gap;
  final ValueChanged<int> onSelect;

  const _Bars({required this.points, required this.selected, required this.gap, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final max = points.fold<double>(0, (m, p) => p.sales > m ? p.sales : m);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, p) in points.indexed)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: gap / 2),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: max <= 0 ? 0 : p.sales / max),
                        duration: Duration(milliseconds: 450 + i * 12),
                        curve: Curves.easeOutCubic,
                        builder: (context, ratio, _) {
                          final isSelected = i == selected;
                          final isLast = i == points.length - 1;
                          return Container(
                            height: (height * ratio).clamp(3, height),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(gap > 5 ? 8 : 3)),
                              gradient: p.sales <= 0
                                  ? null
                                  : LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: isSelected || (selected == null && isLast)
                                          ? [AppTheme.primaryDark, AppTheme.primaryColor]
                                          : [
                                              AppTheme.primaryColor.withValues(alpha: 0.15),
                                              AppTheme.primaryColor.withValues(alpha: 0.45),
                                            ],
                                    ),
                              color: p.sales <= 0 ? Colors.white.withValues(alpha: 0.06) : null,
                              boxShadow: isSelected ? AppTheme.softShadow(AppTheme.primaryColor) : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TrendStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _TrendStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTheme.numeric(fontSize: 16, color: color ?? Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final int value;
  final Map<int, String> labels;
  final ValueChanged<int> onChanged;

  const _RangeToggle({required this.value, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in labels.entries)
            GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: entry.key == value ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: entry.key == value ? AppTheme.onPrimary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
