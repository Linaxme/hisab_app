import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/strings.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/models.dart';
import '../../widgets/amount_keypad.dart';
import '../../widgets/app_panel.dart';
import '../dashboard/day_activity.dart';

/// Count the drawer and match it with live cash; any number of times a day.
Future<void> showCashCheckSheet(BuildContext context) =>
    showAppPanel(context, const _CashCountPanel(), maxWidth: 460);

Future<void> showCashCheckHistory(BuildContext context) =>
    showAppPanel(context, const _CashCheckHistory());

/// "Matched", "Short ৳X" or "Over ৳X" for a counted-minus-expected difference.
(String, Color) closingDiffLabel(Locale locale, double diff) {
  if (diff.abs() < 0.5) return (tr(locale, 'cash_matched'), AppTheme.successColor);
  final amount = CurrencyFormatter.formatNoDecimal(diff.abs());
  return diff < 0
      ? (tr(locale, 'cash_short', params: {'amount': amount}), AppTheme.errorColor)
      : (tr(locale, 'cash_excess', params: {'amount': amount}), AppTheme.warningColor);
}

/// "Adjustment sale ৳X" or "Shortage expense ৳X" for a count's booked difference.
String adjustmentLabel(Locale locale, double adjustment) => tr(
      locale,
      adjustment < 0 ? 'shortage_short' : 'adjusted_short',
      params: {'amount': CurrencyFormatter.formatNoDecimal(adjustment.abs())},
    );

class _CashCountPanel extends ConsumerStatefulWidget {
  const _CashCountPanel();

  @override
  ConsumerState<_CashCountPanel> createState() => _CashCountPanelState();
}

class _CashCountPanelState extends ConsumerState<_CashCountPanel> {
  String _counted = '';
  bool _adjust = true;
  bool _saving = false;

  /// [diff] is counted minus live cash; [adjustment] the part to book.
  ({double expected, double diff, double adjustment})? _figures(double? liveCash) {
    if (liveCash == null) return null;
    final diff = _counted.isEmpty ? 0.0 : double.parse(_counted) - liveCash;
    final adjustment = (_adjust && diff.abs() >= 0.5) ? diff : 0.0;
    return (expected: liveCash + adjustment, diff: diff, adjustment: adjustment);
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
    final figures = _figures(ref.read(dayLiveCashProvider).valueOrNull);
    final repository = ref.read(openingCashRepositoryProvider);
    final user = ref.read(currentUserProvider).value;
    if (_saving || _counted.isEmpty || figures == null || repository == null || user == null) return;
    final locale = ref.read(languageProvider);
    setState(() => _saving = true);
    try {
      await repository.addCashCheck(
        CashCheckModel(
          id: '',
          date: formatDateForQuery(ref.read(selectedDateProvider)),
          counted: double.parse(_counted),
          expected: figures.expected,
          adjustment: figures.adjustment,
          createdBy: user.uid,
          createdByName: user.name,
          createdAt: DateTime.now(),
        ),
        saleLabel: tr(locale, 'adjust_sale_name'),
        expenseLabel: tr(locale, 'shortage_expense_name'),
      );
      if (figures.adjustment != 0) ref.invalidate(liveCashProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(locale, 'cash_check_saved'))),
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
    final liveCash = ref.watch(dayLiveCashProvider).valueOrNull;
    final date = ref.watch(selectedDateProvider);
    String t(String key) => tr(locale, key);
    String money(double v) => CurrencyFormatter.formatNoDecimal(v);

    final counted = double.tryParse(_counted) ?? 0;
    final figures = _figures(liveCash);
    final canAdjust = figures != null && figures.diff.abs() >= 0.5;
    final short = figures != null && figures.diff < 0;
    final adjustColor = short ? AppTheme.errorColor : AppTheme.warningColor;
    final (diffText, diffColor) = (_counted.isEmpty || figures == null)
        ? (t('count_hint'), AppTheme.textSecondary)
        : closingDiffLabel(locale, counted - figures.expected);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: AppPanelFrame(
        title: t('cash_check_title'),
        subtitle: '${DateFormatter.formatDisplay(date)} · ${t('cash_check_sub')}',
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
                      liveCash == null ? '...' : money(liveCash),
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
                          color: adjustColor.withValues(alpha: _adjust ? 0.12 : 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: adjustColor.withValues(alpha: 0.4)),
                        ),
                        child: SwitchListTile(
                          value: _adjust,
                          onChanged: (v) => setState(() => _adjust = v),
                          activeThumbColor: adjustColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          secondary: Icon(
                            short ? Icons.trending_down_rounded : Icons.auto_fix_high_rounded,
                            color: adjustColor,
                          ),
                          title: Text(
                            tr(locale, short ? 'adjust_short' : 'adjust_excess',
                                params: {'amount': money(figures.diff.abs())}),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            t(short ? 'adjust_short_sub' : 'adjust_excess_sub'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 14),
              AmountKeypad(onKey: _press, onClear: () => setState(() => _counted = '')),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (_counted.isEmpty || liveCash == null || _saving) ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fact_check_rounded),
                label: Text(t('cash_check_save')),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact match-cash button, shown on the live-cash label row.
class CashCountCard extends ConsumerWidget {
  const CashCountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final last = ref.watch(cashChecksProvider).valueOrNull?.firstOrNull;
    return FilledButton.icon(
      onPressed: () => showCashCheckSheet(context),
      icon: Icon(last != null ? Icons.verified_rounded : Icons.fact_check_rounded, size: 18),
      label: Text(tr(locale, last != null ? 'recount' : 'cash_check_title')),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Last count's result; opens that day's history.
class CashCountStatus extends ConsumerWidget {
  const CashCountStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final checks = ref.watch(cashChecksProvider).valueOrNull ?? const <CashCheckModel>[];
    final last = checks.firstOrNull;
    if (last == null) return const SizedBox.shrink();
    final (diffText, diffColor) = closingDiffLabel(locale, last.difference);
    return InkWell(
      onTap: () => showCashCheckHistory(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          checks.length > 1
              ? '${tr(locale, 'cash_check_count', params: {'count': '${checks.length}'})} · $diffText'
              : diffText,
          style: TextStyle(color: diffColor, fontWeight: FontWeight.w700, fontSize: 11.5),
        ),
      ),
    );
  }
}

/// Every count of the selected day; the owner can delete a mistaken one.
class _CashCheckHistory extends ConsumerWidget {
  const _CashCheckHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final date = ref.watch(selectedDateProvider);
    final checks = ref.watch(cashChecksProvider).valueOrNull ?? const <CashCheckModel>[];
    final isOwner = ref.watch(currentUserProvider).valueOrNull?.isOwner ?? false;
    String money(double v) => CurrencyFormatter.formatNoDecimal(v);

    return AppPanelFrame(
      title: tr(locale, 'cash_check_history'),
      subtitle: DateFormatter.formatDisplay(date),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: checks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final check = checks[i];
                final (diffText, diffColor) = closingDiffLabel(locale, check.difference);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    '${DateFormatter.formatTime(check.createdAt)} · ${money(check.counted)}',
                    style: AppTheme.numeric(fontSize: 15),
                  ),
                  subtitle: Text(
                    [
                      if (check.createdByName.isNotEmpty) check.createdByName,
                      '${tr(locale, 'expected_cash')} ${money(check.expected - check.adjustment)}',
                      if (check.adjustment != 0) adjustmentLabel(locale, check.adjustment),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(diffText, style: TextStyle(color: diffColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      if (isOwner)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.textSecondary),
                          onPressed: () => _delete(context, ref, check),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => showCashCheckSheet(context),
            icon: const Icon(Icons.fact_check_rounded),
            label: Text(tr(locale, 'cash_check')),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, CashCheckModel check) async {
    final locale = ref.read(languageProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(locale, 'cash_check_delete')),
        content: check.adjustmentId == null
            ? null
            : Text(tr(locale, 'cash_check_delete_adjust', params: {
                'adjustment': adjustmentLabel(locale, check.adjustment),
              })),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr(locale, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text(tr(locale, 'delete')),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(openingCashRepositoryProvider)?.deleteCashCheck(check);
  }
}
