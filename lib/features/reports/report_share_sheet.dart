import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/localization/strings.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../widgets/app_panel.dart';
import '../dashboard/day_activity.dart';
import '../day_close/day_close_sheet.dart';

class ReportLine {
  final String label;
  final String value;
  final Color? color;

  const ReportLine(this.label, this.value, {this.color});
}

class ReportData {
  final String title;
  final String period;
  final String shopName;
  final List<ReportLine> lines;
  final ReportLine highlight;
  final String fileName;

  const ReportData({
    required this.title,
    required this.period,
    required this.shopName,
    required this.lines,
    required this.highlight,
    required this.fileName,
  });

  String toText(String footer) => [
        '*${shopName.isEmpty ? title : shopName}*',
        '$title · $period',
        '',
        for (final l in lines) '${l.label}: ${l.value}',
        '',
        '*${highlight.label}: ${highlight.value}*',
        '',
        '— $footer',
      ].join('\n');
}

Future<void> showReportShareSheet(BuildContext context, ReportData data) =>
    showAppPanel(context, _ReportPanel(data: data), maxWidth: 480);

/// Report of the dashboard's selected day, built from the same streams as the timeline.
ReportData buildDailyReport(WidgetRef ref, {required bool showProfit}) {
  final locale = ref.read(languageProvider);
  String t(String key) => tr(locale, key);
  String money(double v) => CurrencyFormatter.formatNoDecimal(v);

  final date = ref.read(selectedDateProvider);
  final entries = ref.read(dayActivityProvider).valueOrNull ?? const <ActivityEntry>[];
  final opening = ref.read(openingCashProvider).valueOrNull;
  final liveCash = ref.read(dayLiveCashProvider).valueOrNull ?? 0;

  double sum(bool Function(ActivityEntry e) test) =>
      entries.where(test).fold(0, (s, e) => s + e.amount);
  final sales = sum((e) => e.kind == ActivityKind.sale);
  final digital = sum((e) => e.kind == ActivityKind.sale && e.cashEffect == 0);
  final profit = entries.where((e) => e.kind == ActivityKind.sale).fold<double>(0, (s, e) => s + e.profit);

  final closingLines = <ReportLine>[];
  if (opening != null && opening.isClosed) {
    final (diffText, diffColor) = closingDiffLabel(locale, opening.closingDifference);
    closingLines
      ..add(ReportLine(t('counted_cash'), money(opening.closingCounted!)))
      ..add(ReportLine(t('day_close'), diffText, color: diffColor));
    if (opening.closingAdjustment > 0) {
      closingLines.add(ReportLine(t('report_adjustment'), money(opening.closingAdjustment), color: AppTheme.warningColor));
    }
  }

  return ReportData(
    title: t('daily_report'),
    period: DateFormatter.formatDisplay(date),
    shopName: ref.read(currentShopProvider).valueOrNull?.name ?? '',
    fileName: 'report-${formatDateForQuery(date)}.png',
    lines: [
      ReportLine(t('opening_cash'), money(opening?.amount ?? 0)),
      ReportLine(t('total_sales'), money(sales), color: AppTheme.successColor),
      ReportLine(t('cash_sales'), money(sales - digital)),
      ReportLine(t('digital'), money(digital), color: AppTheme.infoColor),
      ReportLine(t('report_credit_sales'), money(sum((e) => e.kind == ActivityKind.creditSale)), color: AppTheme.warningColor),
      ReportLine(t('report_collections'), money(sum((e) => e.kind == ActivityKind.collection))),
      ReportLine(t('report_expenses'), money(sum((e) => e.kind == ActivityKind.expense && !e.isSavings)), color: AppTheme.errorColor),
      if (entries.any((e) => e.isSavings))
        ReportLine(t('savings'), money(sum((e) => e.isSavings)), color: AppTheme.successColor),
      ReportLine(t('report_deposits'), money(sum((e) => e.kind == ActivityKind.deposit))),
      ReportLine(t('report_returns'), money(sum((e) => e.kind == ActivityKind.returned))),
      if (showProfit) ReportLine(t('profit'), money(profit), color: AppTheme.violetColor),
      ...closingLines,
    ],
    highlight: ReportLine(t('live_cash'), money(liveCash)),
  );
}

class _ReportPanel extends ConsumerStatefulWidget {
  final ReportData data;

  const _ReportPanel({required this.data});

  @override
  ConsumerState<_ReportPanel> createState() => _ReportPanelState();
}

class _ReportPanelState extends ConsumerState<_ReportPanel> {
  static final _compactButton = OutlinedButton.styleFrom(
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 10),
  );

  final _boundaryKey = GlobalKey();
  bool _busy = false;

  String get _text => widget.data.toText(tr(ref.read(languageProvider), 'report_footer'));

  void _toast(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(ref.read(languageProvider), key))),
    );
  }

  Future<void> _shareImage() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _busy) return;
    setState(() => _busy = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('no image');
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: widget.data.fileName),
        ],
        fileNameOverrides: [widget.data.fileName],
        subject: widget.data.title,
      ));
    } catch (_) {
      _toast('launch_failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText() async {
    try {
      await SharePlus.instance.share(ShareParams(text: _text, subject: widget.data.title));
    } catch (_) {
      _toast('launch_failed');
    }
  }

  Future<void> _whatsApp() async {
    if (!await ContactLauncher.whatsApp(text: _text)) _toast('launch_failed');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));
    _toast('copied');
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    String t(String key) => tr(locale, key);

    return AppPanelFrame(
      title: t('share_report'),
      subtitle: '${widget.data.title} · ${widget.data.period}',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              key: _boundaryKey,
              child: _ReportCard(data: widget.data, footer: t('report_footer')),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _shareImage,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.image_rounded),
              label: Text(t('share_image')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _whatsApp,
                    style: _compactButton,
                    icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                    label: const FittedBox(child: Text('WhatsApp')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareText,
                    style: _compactButton,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: FittedBox(child: Text(t('share_text'))),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _copy,
                  tooltip: t('copy_text'),
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportData data;
  final String footer;

  const _ReportCard({required this.data, required this.footer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F12), AppTheme.darkCard, AppTheme.darkBackground],
        ),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                child: const Icon(Icons.storefront_rounded, color: AppTheme.onPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.shopName.isEmpty ? data.title : data.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    Text(
                      '${data.title} · ${data.period}',
                      style: const TextStyle(color: AppTheme.goldColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 8),
          for (final line in data.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(line.label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
                  ),
                  Text(
                    line.value,
                    style: AppTheme.numeric(fontSize: 14.5, color: line.color ?? Colors.white),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    data.highlight.label,
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(data.highlight.value, style: AppTheme.numeric(fontSize: 22, color: AppTheme.primaryColor)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$footer · ${DateFormatter.formatDisplay(DateTime.now())} ${DateFormatter.formatTime(DateTime.now())}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
