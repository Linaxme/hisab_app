import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/strings.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/sale_model.dart';
import '../../widgets/amount_keypad.dart';
import '../../widgets/app_panel.dart';
import '../dashboard/day_activity.dart';

Future<void> showDayCloseSheet(BuildContext context) =>
    showAppPanel(context, const _DayClosePanel(), maxWidth: 460);

/// "Matched", "Short ৳X" or "Over ৳X" for a counted-minus-expected difference.
(String, Color) closingDiffLabel(Locale locale, double diff) {
  if (diff.abs() < 0.5) return (tr(locale, 'cash_matched'), AppTheme.successColor);
  final amount = CurrencyFormatter.formatNoDecimal(diff.abs());
  return diff < 0
      ? (tr(locale, 'cash_short', params: {'amount': amount}), AppTheme.errorColor)
      : (tr(locale, 'cash_excess', params: {'amount': amount}), AppTheme.warningColor);
}

class _DayClosePanel extends ConsumerStatefulWidget {
  const _DayClosePanel();

  @override
  ConsumerState<_DayClosePanel> createState() => _DayClosePanelState();
}

class _DayClosePanelState extends ConsumerState<_DayClosePanel> {
  String _counted = '';
  bool _carryForward = true;
  bool _saving = false;
  late bool _adjust;

  @override
  void initState() {
    super.initState();
    final previous = ref.read(openingCashProvider).valueOrNull?.closingCounted;
    if (previous != null && previous > 0) _counted = previous.round().toString();
    _adjust = _adjustmentSale(ref.read(salesByDateProvider).valueOrNull) != null;
  }

  static SaleModel? _adjustmentSale(List<SaleModel>? sales) =>
      sales?.where((s) => s.isAdjustment).firstOrNull;

  /// The drawer figures for the current count. An adjustment booked by an
  /// earlier count is left out of [base] so a recount can resize or drop it.
  ({double base, double excess, double adjustment, double expected})? _figures(
    double? liveCash,
    SaleModel? existing,
  ) {
    if (liveCash == null) return null;
    final base = liveCash - (existing?.sellPrice ?? 0);
    final excess = _counted.isEmpty ? 0.0 : double.parse(_counted) - base;
    final adjustment = (_adjust && excess >= 0.5) ? excess : 0.0;
    return (base: base, excess: excess, adjustment: adjustment, expected: base + adjustment);
  }

  void _press(String key) => setState(() => _counted = applyKeypadKey(_counted, key));

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      _save();
      return KeyEventResult.handled;
    }
    final key = keypadKeyFor(event);
    if (key == null) return KeyEventResult.ignored;
    _press(key);
    return KeyEventResult.handled;
  }

  Future<void> _save() async {
    final existing = _adjustmentSale(ref.read(salesByDateProvider).valueOrNull);
    final figures = _figures(ref.read(dayLiveCashProvider).valueOrNull, existing);
    final repository = ref.read(openingCashRepositoryProvider);
    if (_saving || _counted.isEmpty || figures == null || repository == null) return;

    final locale = ref.read(languageProvider);
    final date = ref.read(selectedDateProvider);
    final uid = ref.read(currentUserProvider).value?.uid ?? '';
    setState(() => _saving = true);
    try {
      await repository.closeDay(
        date: formatDateForQuery(date),
        expected: figures.expected,
        counted: double.parse(_counted),
        closedBy: uid,
        nextDate: _carryForward ? formatDateForQuery(date.add(const Duration(days: 1))) : null,
        adjustment: figures.adjustment,
        adjustmentLabel: tr(locale, 'adjust_sale_name'),
        existingAdjustmentId: existing?.id,
      );
      ref.invalidate(liveCashProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(locale, 'day_closed_msg'))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(locale, 'load_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final expected = ref.watch(dayLiveCashProvider);
    final date = ref.watch(selectedDateProvider);
    String t(String key) => tr(locale, key);
    String money(double v) => CurrencyFormatter.formatNoDecimal(v);

    final counted = double.tryParse(_counted) ?? 0;
    final figures = _figures(
      expected.valueOrNull,
      _adjustmentSale(ref.watch(salesByDateProvider).valueOrNull),
    );
    final expectedValue = figures?.base;
    final canAdjust = figures != null && figures.excess >= 0.5;
    final (diffText, diffColor) = (_counted.isEmpty || figures == null)
        ? (t('count_hint'), AppTheme.textSecondary)
        : closingDiffLabel(locale, counted - figures.expected);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: AppPanelFrame(
        title: t('day_close'),
        subtitle: '${DateFormatter.formatDisplay(date)} · ${t('day_close_sub')}',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_rounded, color: AppTheme.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t('expected_cash'))),
                    Text(
                      expectedValue == null ? '...' : money(expectedValue),
                      style: AppTheme.numeric(fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryColor.withValues(alpha: 0.14), AppTheme.darkCard],
                  ),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text(t('counted_cash'), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        money(counted),
                        style: AppTheme.numeric(fontSize: 40, color: AppTheme.primaryColor, letterSpacing: -1.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: diffColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        diffText,
                        style: TextStyle(color: diffColor, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: canAdjust
                    ? Container(
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: _adjust ? 0.12 : 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
                        ),
                        child: SwitchListTile(
                          value: _adjust,
                          onChanged: (v) => setState(() => _adjust = v),
                          activeThumbColor: AppTheme.warningColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          secondary: const Icon(Icons.auto_fix_high_rounded, color: AppTheme.warningColor),
                          title: Text(
                            tr(locale, 'adjust_excess', params: {'amount': money(figures.excess)}),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(t('adjust_excess_sub'), style: Theme.of(context).textTheme.bodySmall),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 14),
              AmountKeypad(onKey: _press, onClear: () => setState(() => _counted = '')),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _carryForward,
                onChanged: (v) => setState(() => _carryForward = v),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(t('carry_to_next'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  tr(locale, 'carry_to_next_sub', params: {
                    'date': DateFormatter.formatDisplay(date.add(const Duration(days: 1))),
                    'amount': money(counted),
                  }),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: (_counted.isEmpty || expectedValue == null || _saving) ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lock_clock_rounded),
                label: Text(t('close_day_btn')),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashboard prompt to count the drawer, or the result once the day is closed.
class DayCloseCard extends ConsumerWidget {
  const DayCloseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final opening = ref.watch(openingCashProvider).valueOrNull;
    final closed = opening?.isClosed ?? false;

    final (diffText, diffColor) =
        closed ? closingDiffLabel(locale, opening!.closingDifference) : ('', AppTheme.primaryColor);
    final accent = closed ? diffColor : AppTheme.primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showDayCloseSheet(context),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [accent.withValues(alpha: 0.12), AppTheme.darkCard],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(closed ? Icons.verified_rounded : Icons.lock_clock_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(locale, closed ? 'day_closed_title' : 'day_close'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      closed
                          ? [
                              tr(locale, 'counted_short', params: {'amount': CurrencyFormatter.formatNoDecimal(opening!.closingCounted!)}),
                              diffText,
                              if (opening.closingAdjustment > 0)
                                tr(locale, 'adjusted_short', params: {'amount': CurrencyFormatter.formatNoDecimal(opening.closingAdjustment)}),
                            ].join(' · ')
                          : tr(locale, 'day_close_cta'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: closed ? diffColor : AppTheme.textSecondary,
                        fontWeight: closed ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: closed ? Colors.white.withValues(alpha: 0.06) : AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tr(locale, closed ? 'recount' : 'close_day_btn'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: closed ? Colors.white : AppTheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
