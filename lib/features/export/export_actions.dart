import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/localization/strings.dart';
import '../../core/providers/providers.dart';
import 'excel_export.dart';

const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Exports [start]..[end] to an .xlsx file: downloaded on web, shared on phones.
Future<void> exportExcel(
  BuildContext context,
  WidgetRef ref, {
  required DateTime start,
  required DateTime end,
  required String period,
}) async {
  final locale = ref.read(languageProvider);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Expanded(child: Text(tr(locale, 'export_preparing'))),
          ],
        ),
      ),
    ),
  );

  var dialogOpen = true;
  void closeDialog() {
    if (dialogOpen) navigator.pop();
    dialogOpen = false;
  }

  try {
    final data = await loadExportData(ref, start, end);
    final bytes = buildExcel(
      data,
      shopName: ref.read(currentShopProvider).valueOrNull?.name ?? '',
      period: period,
    );
    final fileName = 'hisab_${formatDateForQuery(start)}_${formatDateForQuery(end)}.xlsx';
    final file = XFile.fromData(bytes, mimeType: _xlsxMime, name: fileName);
    closeDialog();

    if (kIsWeb) {
      await file.saveTo(fileName);
      messenger.showSnackBar(SnackBar(content: Text(tr(locale, 'export_saved'))));
    } else {
      await SharePlus.instance.share(ShareParams(
        files: [file],
        fileNameOverrides: [fileName],
        subject: '${tr(locale, 'export_excel')} · $period',
      ));
    }
  } catch (e) {
    debugPrint('Excel export failed: $e');
    closeDialog();
    messenger.showSnackBar(SnackBar(content: Text(tr(locale, 'export_failed'))));
  }
}

/// Asks for a date range, then exports it.
Future<void> pickRangeAndExportExcel(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: today,
    initialDateRange: DateTimeRange(start: DateTime(today.year, today.month, 1), end: today),
    helpText: tr(ref.read(languageProvider), 'export_excel'),
  );
  if (range == null || !context.mounted) return;
  String d(DateTime t) => '${t.day}/${t.month}/${t.year}';
  await exportExcel(
    context,
    ref,
    start: range.start,
    end: range.end,
    period: '${d(range.start)} – ${d(range.end)}',
  );
}
