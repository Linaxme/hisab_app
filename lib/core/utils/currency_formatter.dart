import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Currency formatting utilities
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _formatterNoDecimal = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _compactFormatter = NumberFormat.compact(locale: 'en_US');

  /// Format amount with currency symbol and decimals
  /// Example: ৳1,234.56
  static String format(double amount) {
    return '${AppConstants.currency}${_formatter.format(amount)}';
  }

  /// Format amount with currency symbol without decimals
  /// Example: ৳1,235
  static String formatNoDecimal(double amount) {
    return '${AppConstants.currency}${_formatterNoDecimal.format(amount.round())}';
  }

  /// Format amount in compact form
  /// Example: ৳1.2K, ৳5.5M
  static String formatCompact(double amount) {
    return '${AppConstants.currency}${_compactFormatter.format(amount)}';
  }

  /// Format amount without currency symbol
  /// Example: 1,234.56
  static String formatNumber(double amount) {
    return _formatter.format(amount);
  }

  /// Parse formatted string to double
  static double parse(String formattedAmount) {
    final cleaned = formattedAmount
        .replaceAll(AppConstants.currency, '')
        .replaceAll(',', '')
        .trim();
    return double.tryParse(cleaned) ?? 0.0;
  }
}
