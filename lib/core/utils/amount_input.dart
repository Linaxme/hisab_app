import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import '../localization/strings.dart';
import 'phone_utils.dart';

/// Money typed into a text field: digits (English or Bengali) with up to two decimals.
class AmountInput {
  AmountInput._();

  /// ৳১ কোটি; anything above is almost certainly a typo.
  static const double max = 10000000;

  static const keyboardType = TextInputType.numberWithOptions(decimal: true);

  static final inputFormatters = <TextInputFormatter>[_AmountFormatter()];

  static double? parse(String? value) {
    final amount = double.tryParse(PhoneUtils.toEnglishDigits(value ?? '').trim());
    return amount != null && amount.isFinite ? amount : null;
  }

  /// Error text for the field, or null when it holds a usable amount.
  static String? validate(String? value, Locale locale, {bool allowZero = false}) {
    if ((value ?? '').trim().isEmpty) return tr(locale, 'amount_required');
    final amount = parse(value);
    if (amount == null) return tr(locale, 'amount_invalid');
    if (amount < 0 || (amount == 0 && !allowZero)) return tr(locale, 'amount_positive');
    if (amount > max) return tr(locale, 'amount_too_large');
    return null;
  }

  /// Prefill text for editing: 1200 -> "1200", 99.5 -> "99.5".
  static String format(double amount) {
    final fixed = amount.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _AmountFormatter extends TextInputFormatter {
  static final _allowed = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = PhoneUtils.toEnglishDigits(newValue.text);
    if (!_allowed.hasMatch(text)) return oldValue;
    // Bengali and English digits are one code unit each, so the selection still fits.
    return newValue.copyWith(text: text);
  }
}
