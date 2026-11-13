import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../data/models/models.dart';
import '../expenses/expense_groups.dart';

/// Everything recorded between two dates, read once for an export.
class ExportData {
  final DateTime start;
  final DateTime end;
  final List<SaleModel> sales;
  final List<ExpenseModel> expenses;
  final List<DepositModel> deposits;
  final List<ReturnModel> returns;
  final List<CreditSaleModel> creditSales;
  final List<CreditCollectionModel> collections;
  final Map<String, OpeningCashModel> openingCash;

  /// The latest drawer count of each date.
  final Map<String, CashCheckModel> lastCounts;
  final Set<String> savingsIds;

  /// Customer name for every credit sale a collection in range belongs to.
  final Map<String, String> creditCustomers;

  ExportData({
    required this.start,
    required this.end,
    required this.sales,
    required this.expenses,
    required this.deposits,
    required this.returns,
    required this.creditSales,
    required this.collections,
    required this.openingCash,
    required this.lastCounts,
    required this.savingsIds,
    required this.creditCustomers,
  });
}

Future<ExportData> loadExportData(WidgetRef ref, DateTime start, DateTime end) async {
  final sales = ref.read(salesRepositoryProvider);
  final expenses = ref.read(expensesRepositoryProvider);
  final deposits = ref.read(depositsRepositoryProvider);
  final returns = ref.read(returnsRepositoryProvider);
  final credit = ref.read(creditRepositoryProvider);
  final opening = ref.read(openingCashRepositoryProvider);
  if (sales == null || expenses == null || deposits == null || returns == null ||
      credit == null || opening == null) {
    throw StateError('shop not loaded');
  }

  final from = formatDateForQuery(start);
  final to = formatDateForQuery(end);
  final results = await Future.wait([
    sales.getSalesByDateRange(from, to),
    expenses.getExpensesByDateRange(from, to),
    deposits.getDepositsByDateRange(from, to),
    returns.getReturnsByDateRange(from, to),
    credit.getCreditSalesByDateRange(from, to),
    credit.getCollectionsByDateRange(from, to),
    opening.getOpeningCashByDateRange(from, to),
    expenses.getCategories(),
    opening.getCashChecksByDateRange(from, to),
  ]);

  final lastCounts = <String, CashCheckModel>{};
  for (final c in results[8] as List<CashCheckModel>) {
    final current = lastCounts[c.date];
    if (current == null || c.createdAt.isAfter(current.createdAt)) lastCounts[c.date] = c;
  }

  final creditSales = results[4] as List<CreditSaleModel>;
  final collections = results[5] as List<CreditCollectionModel>;
  final customers = {
    for (final c in creditSales) c.id: _customerLabel(c),
  };
  for (final id in {for (final c in collections) c.creditSaleId}) {
    if (customers.containsKey(id)) continue;
    final sale = await credit.getCreditSale(id);
    customers[id] = sale == null ? '' : _customerLabel(sale);
  }

  return ExportData(
    start: start,
    end: end,
    sales: results[0] as List<SaleModel>,
    expenses: results[1] as List<ExpenseModel>,
    deposits: results[2] as List<DepositModel>,
    returns: results[3] as List<ReturnModel>,
    creditSales: creditSales,
    collections: collections,
    openingCash: {for (final o in results[6] as List<OpeningCashModel>) o.id: o},
    lastCounts: lastCounts,
    savingsIds: {
      for (final c in results[7] as List<ExpenseCategoryModel>)
        if (c.isSavings) c.id,
    },
    creditCustomers: customers,
  );
}

String _customerLabel(CreditSaleModel c) =>
    [c.customerName, c.customerPhone].where((s) => s != null && s.trim().isNotEmpty).join(' · ');

final _headerStyle = xl.CellStyle(
  bold: true,
  backgroundColorHex: xl.ExcelColor.fromHexString('#C6F24E'),
  fontColorHex: xl.ExcelColor.fromHexString('#0A0B0D'),
  verticalAlign: xl.VerticalAlign.Center,
  textWrapping: xl.TextWrapping.WrapText,
);
final _titleStyle = xl.CellStyle(bold: true, fontSize: 14);
final _moneyStyle = xl.CellStyle(numberFormat: xl.NumFormat.standard_3);
final _totalLabelStyle = xl.CellStyle(
  bold: true,
  backgroundColorHex: xl.ExcelColor.fromHexString('#E2FC8F'),
);
final _totalMoneyStyle = xl.CellStyle(
  bold: true,
  backgroundColorHex: xl.ExcelColor.fromHexString('#E2FC8F'),
  numberFormat: xl.NumFormat.standard_3,
);
final _groupStyle = xl.CellStyle(
  bold: true,
  backgroundColorHex: xl.ExcelColor.fromHexString('#F4FFD6'),
);
final _groupMoneyStyle = xl.CellStyle(
  bold: true,
  backgroundColorHex: xl.ExcelColor.fromHexString('#F4FFD6'),
  numberFormat: xl.NumFormat.standard_3,
);

/// Writes rows top to bottom; numbers are formatted as money unless given as int.
class _SheetWriter {
  final xl.Sheet sheet;
  int row = 0;

  _SheetWriter(this.sheet);

  void widths(List<double> widths) {
    for (final (i, w) in widths.indexed) {
      sheet.setColumnWidth(i, w);
    }
  }

  void write(List<Object?> values, {xl.CellStyle? text, xl.CellStyle? money}) {
    for (final (col, v) in values.indexed) {
      if (v == null) continue;
      final index = xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);
      switch (v) {
        case int():
          sheet.updateCell(index, xl.IntCellValue(v), cellStyle: text);
        case num():
          sheet.updateCell(index, xl.DoubleCellValue(v.toDouble()), cellStyle: money ?? _moneyStyle);
        default:
          sheet.updateCell(index, xl.TextCellValue('$v'), cellStyle: text);
      }
    }
    row++;
  }

  void header(List<String> labels) => write(labels, text: _headerStyle);

  void total(List<Object?> values) => write(values, text: _totalLabelStyle, money: _totalMoneyStyle);

  void skip([int n = 1]) => row += n;
}

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

double _sum<T>(Iterable<T> items, double Function(T) amount) =>
    items.fold(0.0, (s, e) => s + amount(e));

int _byDateThenTime(String aDate, DateTime aTime, String bDate, DateTime bTime) {
  final d = aDate.compareTo(bDate);
  return d != 0 ? d : aTime.compareTo(bTime);
}

/// Builds the workbook: daily summary, sales, expenses, expense heads,
/// deposits, returns and credit, one sheet each.
Uint8List buildExcel(ExportData data, {required String shopName, required String period}) {
  final excel = xl.Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  const summaryName = 'সারাংশ';
  excel.rename(defaultSheet, summaryName);

  _writeSummary(_SheetWriter(excel[summaryName]), data, shopName, period);
  _writeSales(_SheetWriter(excel['বিক্রয়']), data);
  _writeExpenses(_SheetWriter(excel['খরচ']), data);
  _writeExpenseHeads(_SheetWriter(excel['খাত অনুযায়ী']), data);
  _writeDeposits(_SheetWriter(excel['জমা']), data);
  _writeReturns(_SheetWriter(excel['ফেরত']), data);
  _writeCredit(_SheetWriter(excel['বাকি']), data);

  excel.setDefaultSheet(summaryName);
  final bytes = excel.encode();
  if (bytes == null) throw StateError('excel encode failed');
  return Uint8List.fromList(bytes);
}

void _writeSummary(_SheetWriter w, ExportData data, String shopName, String period) {
  w.widths([12, 11, 12, 12, 12, 11, 11, 13, 10, 11, 10, 11, 11, 13, 12, 11]);
  w.write(['আমার দোকান · $shopName'], text: _titleStyle);
  w.write(['হিসাবের সময়: $period']);
  w.skip();
  w.header([
    'তারিখ', 'শুরুর ক্যাশ', 'মোট বিক্রয়', 'নগদ বিক্রয়', 'MFS বিক্রয়', 'লাভ',
    'খরচ', 'ক্যাশ থেকে খরচ', 'সঞ্চয়', 'ক্যাশ জমা', 'ফেরত', 'বাকি দেওয়া',
    'বাকি আদায়', 'দিনশেষ ক্যাশ (হিসাব)', 'শেষ গোনা ক্যাশ', 'গোনায় পার্থক্য',
  ]);

  final today = DateTime.now();
  final last = data.end.isAfter(today) ? DateTime(today.year, today.month, today.day) : data.end;
  final totals = List<double>.filled(16, 0);
  for (var day = data.start; !day.isAfter(last); day = DateTime(day.year, day.month, day.day + 1)) {
    final date = formatDateForQuery(day);
    bool on(String d) => d == date;
    final sales = data.sales.where((s) => on(s.date));
    final expenses = data.expenses.where((e) => on(e.date));
    final spending = expenses.where((e) => !data.savingsIds.contains(e.categoryId));
    final returns = data.returns.where((r) => on(r.date));
    final opening = data.openingCash[date];

    final cashSales = _sum(sales.where((s) => s.isCash), (s) => s.sellPrice);
    final manualDeposits = _sum(data.deposits.where((d) => on(d.date) && !d.isAutoCreated), (d) => d.amount);
    final collected = _sum(data.collections.where((c) => on(c.date)), (c) => c.amount);
    final allCashExpenses = _sum(expenses.where((e) => e.isCash), (e) => e.amount);
    final cashReturns = _sum(returns.where((r) => r.isCash), (r) => r.amount);
    final openingCash = opening?.amount ?? 0;
    final closing = openingCash + cashSales + collected - manualDeposits - allCashExpenses - cashReturns;

    final values = <double>[
      openingCash,
      _sum(sales, (s) => s.sellPrice),
      cashSales,
      _sum(sales.where((s) => !s.isCash), (s) => s.sellPrice),
      _sum(sales, (s) => s.profit),
      _sum(spending, (e) => e.amount),
      _sum(spending.where((e) => e.isCash), (e) => e.amount),
      _sum(expenses.where((e) => data.savingsIds.contains(e.categoryId)), (e) => e.amount),
      manualDeposits,
      _sum(returns, (r) => r.amount),
      _sum(data.creditSales.where((c) => on(c.date)), (c) => c.amount),
      collected,
    ];
    final hasActivity = values.any((v) => v != 0) || opening != null;
    if (!hasActivity) {
      w.write([date]);
      continue;
    }
    for (final (i, v) in values.indexed) {
      totals[i + 1] += v;
    }
    final lastCount = data.lastCounts[date];
    final counted = lastCount?.counted ?? opening?.closingCounted;
    w.write([
      date,
      ...values,
      closing,
      counted,
      lastCount?.difference ?? (counted == null ? null : counted - closing),
    ]);
  }

  w.total([
    'মোট',
    null,
    for (var i = 2; i <= 12; i++) totals[i],
  ]);
  w.skip();
  w.write(['দিনশেষ ক্যাশ = শুরুর ক্যাশ + নগদ বিক্রয় + বাকি আদায় − ক্যাশ জমা − ক্যাশ থেকে খরচ ও সঞ্চয় − নগদ ফেরত']);
}

void _writeSales(_SheetWriter w, ExportData data) {
  w.widths([12, 8, 30, 12, 11, 10]);
  w.header(['তারিখ', 'সময়', 'বিবরণ', 'টাকা', 'লাভ', 'পেমেন্ট']);
  final sales = [...data.sales]
    ..sort((a, b) => _byDateThenTime(a.date, a.createdAt, b.date, b.createdAt));
  for (final s in sales) {
    w.write([
      s.date,
      _time(s.createdAt),
      s.isAdjustment ? '${s.productName} (ক্যাশ গোনার সমন্বয়)' : s.productName,
      s.sellPrice,
      s.profit,
      s.isCash ? 'নগদ' : 'MFS',
    ]);
  }
  w.total(['মোট', '${sales.length}টি', null, _sum(sales, (s) => s.sellPrice), _sum(sales, (s) => s.profit)]);
}

void _writeExpenses(_SheetWriter w, ExportData data) {
  w.widths([12, 8, 20, 20, 30, 12, 14]);
  w.header(['তারিখ', 'সময়', 'খাত', 'সাব-ক্যাটাগরি', 'নোট', 'টাকা', 'পেমেন্ট']);
  final expenses = [...data.expenses]
    ..sort((a, b) => _byDateThenTime(a.date, a.createdAt, b.date, b.createdAt));
  for (final e in expenses) {
    w.write([
      e.date,
      _time(e.createdAt),
      data.savingsIds.contains(e.categoryId) ? '${e.categoryName} (সঞ্চয়)' : e.categoryName,
      e.subCategoryName ?? '',
      e.note ?? '',
      e.amount,
      e.isCash ? 'ক্যাশ থেকে' : 'ক্যাশের বাইরে',
    ]);
  }
  w.total(['মোট', '${expenses.length}টি', null, null, null, _sum(expenses, (e) => e.amount)]);
}

void _writeExpenseHeads(_SheetWriter w, ExportData data) {
  w.widths([22, 24, 10, 13, 9]);
  w.header(['খাত', 'সাব-ক্যাটাগরি', 'সংখ্যা', 'টাকা', '% (খাতের)']);

  void section(List<CategoryGroup> groups) {
    for (final g in groups) {
      w.write([g.name, '', g.items.length, g.total], text: _groupStyle, money: _groupMoneyStyle);
      if (!g.hasSubcategories) continue;
      for (final s in g.sortedSubs) {
        w.write([
          '',
          s.name,
          s.items.length,
          s.total,
          g.total <= 0 ? null : '${(s.total / g.total * 100).round()}%',
        ]);
      }
    }
  }

  final spending = data.expenses.where((e) => !data.savingsIds.contains(e.categoryId));
  section(groupExpenses(spending));
  w.total(['মোট খরচ', null, spending.length, _sum(spending, (e) => e.amount)]);

  final savings = data.expenses.where((e) => data.savingsIds.contains(e.categoryId));
  if (savings.isNotEmpty) {
    w.skip();
    w.header(['সঞ্চয় (খরচে গোনা হয়নি)', '', '', '', '']);
    section(groupExpenses(savings));
    w.total(['মোট সঞ্চয়', null, savings.length, _sum(savings, (e) => e.amount)]);
  }
}

void _writeDeposits(_SheetWriter w, ExportData data) {
  w.widths([12, 8, 12, 20, 30]);
  w.header(['তারিখ', 'সময়', 'টাকা', 'ধরন', 'নোট']);
  final deposits = [...data.deposits]
    ..sort((a, b) => _byDateThenTime(a.date, a.createdAt, b.date, b.createdAt));
  for (final d in deposits) {
    w.write([
      d.date,
      _time(d.createdAt),
      d.amount,
      d.isAutoCreated ? 'MFS বিক্রয় থেকে' : 'ক্যাশ থেকে জমা',
      d.note ?? '',
    ]);
  }
  final manual = deposits.where((d) => !d.isAutoCreated);
  w.total(['মোট', null, _sum(deposits, (d) => d.amount)]);
  w.total(['ক্যাশ থেকে জমা', null, _sum(manual, (d) => d.amount)]);
}

void _writeReturns(_SheetWriter w, ExportData data) {
  w.widths([12, 8, 12, 14, 30]);
  w.header(['তারিখ', 'সময়', 'টাকা', 'পেমেন্ট', 'নোট']);
  final returns = [...data.returns]
    ..sort((a, b) => _byDateThenTime(a.date, a.createdAt, b.date, b.createdAt));
  for (final r in returns) {
    w.write([r.date, _time(r.createdAt), r.amount, r.isCash ? 'নগদ' : 'MFS', r.note ?? '']);
  }
  w.total(['মোট', '${returns.length}টি', _sum(returns, (r) => r.amount)]);
}

void _writeCredit(_SheetWriter w, ExportData data) {
  w.widths([12, 28, 12, 12, 12]);
  w.write(['এই সময়ে দেওয়া বাকি'], text: _titleStyle);
  w.header(['তারিখ', 'কাস্টমার', 'বাকি', 'আদায় হয়েছে', 'বাকি আছে']);
  final credit = [...data.creditSales]
    ..sort((a, b) => _byDateThenTime(a.date, a.createdAt, b.date, b.createdAt));
  for (final c in credit) {
    w.write([c.date, _customerLabel(c), c.amount, c.collectedAmount, c.remainingAmount]);
  }
  w.total([
    'মোট',
    '${credit.length}টি',
    _sum(credit, (c) => c.amount),
    _sum(credit, (c) => c.collectedAmount),
    _sum(credit, (c) => c.remainingAmount),
  ]);

  w.skip(2);
  w.write(['এই সময়ে বাকি আদায়'], text: _titleStyle);
  w.header(['তারিখ', 'কাস্টমার', 'টাকা']);
  final collections = [...data.collections]
    ..sort((a, b) => _byDateThenTime(a.date, a.createdAt, b.date, b.createdAt));
  for (final c in collections) {
    w.write([c.date, data.creditCustomers[c.creditSaleId] ?? '', c.amount]);
  }
  w.total(['মোট', '${collections.length}টি', _sum(collections, (c) => c.amount)]);
}
