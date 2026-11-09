import 'package:intl/intl.dart';

/// Date formatting utilities
class DateFormatter {
  DateFormatter._();

  // Stored dates always use ASCII digits, whatever Intl.defaultLocale is.
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd', 'en_US');
  static final DateFormat _displayFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');

  /// Get date string for storage (yyyy-MM-dd)
  static String toDateString(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Get today's date string
  static String get today => toDateString(DateTime.now());

  /// Parse date string to DateTime
  static DateTime parseDate(String dateString) {
    return _dateFormat.parse(dateString);
  }

  /// Format for display (dd MMM yyyy)
  static String formatDisplay(DateTime date) {
    return _displayFormat.format(date);
  }

  /// Format for display from string
  static String formatDisplayFromString(String dateString) {
    return _displayFormat.format(parseDate(dateString));
  }

  /// Format month year (MMMM yyyy)
  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  /// Format time (hh:mm a)
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }

  /// Get current month string (yyyy-MM)
  static String get currentMonth {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Check if date is today
  static bool isToday(String dateString) {
    return dateString == today;
  }
}
