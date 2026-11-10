import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/dashboard_preferences_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/localization/strings.dart';
import '../../../widgets/entry_form.dart';
import '../../../widgets/modern_widgets.dart';
import '../../../data/models/models.dart';
import '../../credit/screens/credit_screen.dart';
import '../../deposits/screens/deposits_screen.dart';
import '../../expenses/screens/expenses_screen.dart';
import '../../returns/screens/returns_screen.dart';
import '../../sales/screens/sales_screen.dart';
import '../day_activity.dart';
import '../sales_trend.dart';
import '../../day_close/day_close_sheet.dart';
import '../../reports/report_share_sheet.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../widgets/sync_indicator.dart';

String _money<T>(AsyncValue<T> value, double Function(T data) pick) => value.when(
      data: (data) => CurrencyFormatter.formatNoDecimal(pick(data)),
      loading: () => '...',
      error: (_, _) => CurrencyFormatter.formatNoDecimal(0),
    );

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
            error: (_, _) => Center(child: Text(tr(locale, 'error_loading_shop'))),
          );
        },
        loading: () => const DashboardSkeletonLoader(),
        error: (_, _) => Center(child: Text(tr(locale, 'error_loading_user'))),
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
    final locale = ref.watch(languageProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(salesTotalsProvider);
        ref.invalidate(expensesTotalsProvider);
        ref.invalidate(depositsTotalProvider);
        ref.invalidate(returnsTotalProvider);
        ref.invalidate(openingCashProvider);
        ref.invalidate(liveCashProvider);
        ref.invalidate(salesByDateProvider);
        ref.invalidate(expensesByDateProvider);
        ref.invalidate(creditSalesByDateProvider);
        ref.invalidate(collectionsByDateProvider);
        ref.invalidate(depositsByDateProvider);
        ref.invalidate(returnsByDateProvider);
        ref.read(liveDaySalesTotalsProvider).clear();
        ref.invalidate(daySalesTotalProvider);
        ref.invalidate(salesTrendProvider);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return width >= 1000
              ? _buildDesktop(locale)
              : _buildMobile(locale, rounded: width >= Breakpoints.tablet);
        },
      ),
    );
  }

  Widget _hero({required bool rounded}) => _HeroHeader(
        userName: userName,
        shopName: shopName,
        isOwner: isOwner,
        rounded: rounded,
      ).animate().fadeIn(duration: 400.ms);

  Widget _buildMobile(Locale locale, {required bool rounded}) {
    final hero = _hero(rounded: rounded);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: rounded ? const EdgeInsets.all(24) : EdgeInsets.zero,
      children: [
        hero,
        Padding(
          padding: rounded
              ? const EdgeInsets.only(top: 20)
              : const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DateSelector().animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 16),
              _FlowCard(showProfit: showProfit).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
              if (isOwner) ...[
                const SizedBox(height: 12),
                const DayCloseCard().animate().fadeIn(delay: 180.ms),
              ],
              const SizedBox(height: 24),
              SectionHeader(title: tr(locale, 'today_activity')),
              const SizedBox(height: 12),
              const _ActivityTimeline().animate().fadeIn(delay: 220.ms).slideY(begin: 0.05),
              const SizedBox(height: 24),
              const SalesTrendCard().animate().fadeIn(delay: 260.ms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktop(Locale locale) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hero(rounded: true),
                  const SizedBox(height: 16),
                  const _DateSelector().animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 16),
                  _FlowCard(showProfit: showProfit).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                  if (isOwner) ...[
                    const SizedBox(height: 16),
                    const DayCloseCard().animate().fadeIn(delay: 180.ms),
                  ],
                  const SizedBox(height: 16),
                  const SalesTrendCard().animate().fadeIn(delay: 220.ms),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(title: tr(locale, 'today_activity')),
                  const SizedBox(height: 12),
                  const _ActivityTimeline(),
                ],
              ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.05),
            ),
          ],
        ),
      ],
    );
  }
}

/// Gradient header with greeting, shop and live cash
class _HeroHeader extends ConsumerWidget {
  final String userName;
  final String shopName;
  final bool isOwner;
  final bool rounded;

  const _HeroHeader({
    required this.userName,
    required this.shopName,
    required this.isOwner,
    this.rounded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final liveCash = ref.watch(dayLiveCashProvider);
    final openingCash = ref.watch(openingCashProvider);
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: rounded
            ? BorderRadius.circular(28)
            : const BorderRadius.vertical(bottom: Radius.circular(32)),
        border: rounded
            ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2))
            : Border(
                bottom: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
              ),
        boxShadow: rounded ? AppTheme.softShadow(AppTheme.primaryColor) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -90,
            top: -110,
            child: AppTheme.glowBlob(size: 320, opacity: 0.32),
          ),
          Positioned(
            left: -80,
            bottom: -120,
            child: AppTheme.glowBlob(size: 260, color: AppTheme.goldColor, opacity: 0.16),
          ),
          SafeArea(
            bottom: false,
            top: !rounded,
            child: Padding(
              padding: rounded
                  ? const EdgeInsets.all(28)
                  : const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.softShadow(AppTheme.primaryColor),
                        ),
                        child: Text(
                          initial,
                          style: AppTheme.numeric(
                            color: AppTheme.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(locale, 'welcome'),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const SyncIndicator(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.goldColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 14, color: AppTheme.goldColor),
                        const SizedBox(width: 6),
                        Text(
                          shopName,
                          style: const TextStyle(
                            color: AppTheme.goldColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.softShadow(AppTheme.primaryColor, strength: 3),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fade(begin: 0.35, end: 1, duration: 900.ms),
                      const SizedBox(width: 8),
                      Text(
                        tr(locale, 'live_cash').toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, AppTheme.primaryLight, AppTheme.primaryColor],
                        stops: [0.0, 0.55, 1.0],
                      ).createShader(bounds),
                      child: Text(
                        _money(liveCash, (v) => v),
                        style: AppTheme.numeric(
                          color: Colors.white,
                          fontSize: 46,
                          letterSpacing: -2,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: isOwner ? () => showOpeningCashDialog(context, ref) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isOwner
                                  ? tr(
                                      locale,
                                      'opening_cash_caption',
                                      params: {'amount': _money(openingCash, (v) => v?.amount ?? 0)},
                                    )
                                  : '${tr(locale, 'opening_cash')}: ${_money(openingCash, (v) => v?.amount ?? 0)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isOwner) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cash in vs cash out for the selected day, with a split bar.
class _FlowCard extends ConsumerWidget {
  final bool showProfit;

  const _FlowCard({required this.showProfit});

  static int _flex(double v) => v <= 0 ? 0 : (v * 100).round().clamp(1, 1 << 30);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final prefs = ref.watch(dashboardPreferencesProvider);
    final flow = ref.watch(dayFlowProvider).valueOrNull ?? const DayFlow();
    String t(String key) => tr(locale, key);
    String money(double v) => CurrencyFormatter.formatNoDecimal(v);

    final net = flow.net;
    final netColor = net >= 0 ? AppTheme.successColor : AppTheme.errorColor;
    final inFlex = _flex(flow.cashIn);
    final outFlex = _flex(flow.cashOut);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(t('today_flow'), style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                onPressed: () => showReportShareSheet(context, buildDailyReport(ref, showProfit: showProfit)),
                tooltip: t('share_report'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.ios_share_rounded, size: 20, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: netColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: netColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${t('net_flow')} ${net >= 0 ? '+' : '−'}${money(net.abs())}',
                  style: AppTheme.numeric(fontSize: 12.5, color: netColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FlowFigure(
                  icon: Icons.south_west_rounded,
                  label: t('cash_in'),
                  value: money(flow.cashIn),
                  color: AppTheme.successColor,
                ),
              ),
              Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.07)),
              const SizedBox(width: 16),
              Expanded(
                child: _FlowFigure(
                  icon: Icons.north_east_rounded,
                  label: t('cash_out'),
                  value: money(flow.cashOut),
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: inFlex + outFlex == 0
                  ? ColoredBox(color: Colors.white.withValues(alpha: 0.06))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (inFlex > 0)
                          Expanded(
                            flex: inFlex,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [Color(0xFF059669), AppTheme.successColor]),
                              ),
                            ),
                          ),
                        if (inFlex > 0 && outFlex > 0) const SizedBox(width: 3),
                        if (outFlex > 0)
                          Expanded(
                            flex: outFlex,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [AppTheme.errorColor, Color(0xFFE11D48)]),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _MiniStatGrid(
            children: [
              if (prefs.showTodaySales)
                _MiniStat(label: t('total_sales'), value: money(flow.totalSales), color: AppTheme.successColor),
              _MiniStat(label: t('digital'), value: money(flow.digitalSales), color: AppTheme.infoColor),
              if (prefs.showTodayExpenses)
                _MiniStat(label: t('today_expenses'), value: money(flow.totalExpenses), color: AppTheme.errorColor),
              if (flow.savings > 0)
                _MiniStat(label: t('savings'), value: money(flow.savings), color: AppTheme.successColor),
              if (prefs.showReturns)
                _MiniStat(label: t('report_returns'), value: money(flow.returns), color: AppTheme.violetColor),
              if (showProfit)
                _MiniStat(label: t('today_profit'), value: money(flow.profit), color: AppTheme.violetColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowFigure extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _FlowFigure({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: AppTheme.numeric(fontSize: 22, color: color)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Equal-width tiles, at least three per row so phones need only two rows.
class _MiniStatGrid extends StatelessWidget {
  final List<Widget> children;

  const _MiniStatGrid({required this.children});

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / 150).floor().clamp(3, children.length.clamp(3, 6));
        final tileWidth = (width - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [for (final child in children) SizedBox(width: tileWidth, child: child)],
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(width: 6),
            Text(value, style: AppTheme.numeric(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Transactions of the selected day, newest first; the latest few are shown
/// and the rest open in steps.
class _ActivityTimeline extends ConsumerStatefulWidget {
  const _ActivityTimeline();

  @override
  ConsumerState<_ActivityTimeline> createState() => _ActivityTimelineState();
}

class _ActivityTimelineState extends ConsumerState<_ActivityTimeline> {
  static const _initialCount = 5;
  static const _step = 10;
  int _visible = _initialCount;

  static const _style = <ActivityKind, (String, IconData, Color)>{
    ActivityKind.sale: ('tl_sale', Icons.point_of_sale_rounded, AppTheme.successColor),
    ActivityKind.expense: ('tl_expense', Icons.receipt_long_rounded, AppTheme.errorColor),
    ActivityKind.creditSale: ('tl_credit_sale', Icons.handshake_rounded, AppTheme.warningColor),
    ActivityKind.collection: ('tl_collection', Icons.call_received_rounded, AppTheme.primaryColor),
    ActivityKind.deposit: ('tl_deposit', Icons.savings_rounded, AppTheme.accentColor),
    ActivityKind.returned: ('tl_return', Icons.assignment_return_rounded, AppTheme.violetColor),
  };
  static const _savingsStyle = ('tl_savings', Icons.savings_rounded, AppTheme.successColor);

  static (String, IconData, Color) _styleOf(ActivityEntry entry) =>
      entry.isSavings ? _savingsStyle : _style[entry.kind]!;

  Widget? _editForm(ActivityEntry entry) => switch (entry.source) {
        final SaleModel s => SaleFormSheet(sale: s),
        final ExpenseModel e => ExpenseFormSheet(expense: e),
        final CreditSaleModel c => CreditSaleFormSheet(creditSale: c),
        final DepositModel d => DepositFormSheet(deposit: d),
        final ReturnModel r => ReturnFormSheet(returnItem: r),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final activity = ref.watch(dayActivityProvider);
    ref.listen(selectedDateProvider, (_, _) => setState(() => _visible = _initialCount));
    String t(String key) => tr(locale, key);

    return activity.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Center(child: Text(t('load_error'))),
      data: (entries) {
        if (entries.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: AppTheme.cardDecoration(context, radius: 24),
            child: Column(
              children: [
                Icon(Icons.timeline_rounded, size: 44, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
                const SizedBox(height: 12),
                Text(t('no_activity'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  t('no_activity_sub'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        final shown = entries.take(_visible).toList();
        final remaining = entries.length - shown.length;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: AppTheme.cardDecoration(context, radius: 24),
          child: Column(
            children: [
              for (final (i, entry) in shown.indexed)
                _TimelineRow(
                  entry: entry,
                  style: _styleOf(entry),
                  title: entry.label ?? t(_styleOf(entry).$1),
                  kindLabel: entry.label == null ? null : t(_styleOf(entry).$1),
                  effectLabel: switch (entry.cashEffect) {
                    0 when entry.kind == ActivityKind.sale => t('digital'),
                    0 => t('not_in_cash'),
                    > 0 => t('cash_in'),
                    _ => t('cash_out'),
                  },
                  isFirst: i == 0,
                  isLast: i == shown.length - 1,
                  onTap: switch (_editForm(entry)) {
                    final form? => () => showEntryForm(context, form),
                    null => null,
                  },
                ),
              if (entries.length > _initialCount)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(locale, 'shown_of', params: {
                            'shown': '${shown.length}',
                            'total': '${entries.length}',
                          }),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (shown.length > _initialCount)
                        TextButton(
                          onPressed: () => setState(() => _visible = _initialCount),
                          child: Text(t('show_less')),
                        ),
                      if (remaining > 0)
                        FilledButton.tonalIcon(
                          onPressed: () => setState(() => _visible += _step),
                          icon: const Icon(Icons.expand_more_rounded, size: 18),
                          label: Text(tr(locale, 'show_more', params: {'count': '$remaining'})),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final ActivityEntry entry;
  final (String, IconData, Color) style;
  final String title;
  final String? kindLabel;
  final String effectLabel;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  const _TimelineRow({
    required this.entry,
    required this.style,
    required this.title,
    required this.kindLabel,
    required this.effectLabel,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (_, icon, color) = style;
    final time =
        '${entry.time.hour.toString().padLeft(2, '0')}:${entry.time.minute.toString().padLeft(2, '0')}';
    final amountColor = switch (entry.cashEffect) {
      _ when entry.isSavings => AppTheme.successColor,
      > 0 => AppTheme.successColor,
      < 0 => AppTheme.errorColor,
      _ => AppTheme.infoColor,
    };
    final sign = switch (entry.cashEffect) {
      > 0 => '+',
      < 0 => '−',
      _ => '',
    };
    final line = Colors.white.withValues(alpha: 0.08);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 42,
                child: Center(
                  child: Text(time, style: AppTheme.numeric(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(
                width: 34,
                child: Column(
                  children: [
                    Expanded(child: Container(width: 2, color: isFirst ? Colors.transparent : line)),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Icon(icon, size: 15, color: color),
                    ),
                    Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : line)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      Text(
                        kindLabel == null ? effectLabel : '$kindLabel · $effectLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Center(
                child: Text(
                  '$sign${CurrencyFormatter.formatNoDecimal(entry.amount)}',
                  style: AppTheme.numeric(fontSize: 15.5, color: amountColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showOpeningCashDialog(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  final openingCash = ref.read(openingCashProvider).value;
  final locale = ref.read(languageProvider);
  if (openingCash != null) {
    controller.text = openingCash.amount.toStringAsFixed(0);
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const IconBadge(
            icon: Icons.account_balance_wallet_rounded,
            color: AppTheme.primaryColor,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Text(tr(locale, 'opening_cash_dialog_title')),
        ],
      ),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(
          labelText: tr(locale, 'amount'),
          prefixText: '৳ ',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(locale, 'cancel')),
        ),
        FilledButton(
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
          child: Text(tr(locale, 'save')),
        ),
      ],
    ),
  );
}

class _DateSelector extends ConsumerWidget {
  const _DateSelector();

  String _formatDate(DateTime date, Locale locale) {
    final isBangla = locale.languageCode == 'bn';
    final weekdays = isBangla
        ? ['সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার']
        : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = isBangla
        ? [
            'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
            'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
          ]
        : [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December',
          ];

    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final locale = ref.watch(languageProvider);
    final today = DateTime.now();
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: AppTheme.cardDecoration(context, radius: 18),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'আগের দিন',
            onPressed: () => ref.read(selectedDateProvider.notifier).state =
                selectedDate.subtract(const Duration(days: 1)),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _showDatePicker(context, ref, selectedDate),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _formatDate(selectedDate, locale),
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      StatusPill(label: tr(locale, 'today'), color: AppTheme.primaryColor),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _RoundIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'পরের দিন',
            onPressed: isToday
                ? null
                : () => ref.read(selectedDateProvider.notifier).state =
                    selectedDate.add(const Duration(days: 1)),
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
    );

    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _RoundIconButton({required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        foregroundColor: AppTheme.primaryColor,
        disabledBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
