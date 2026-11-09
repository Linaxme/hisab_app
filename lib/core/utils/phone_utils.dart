import 'package:flutter/services.dart';

/// Bangladeshi mobile numbers: typed in English or Bengali digits, stored as 01XXXXXXXXX.
class PhoneUtils {
  PhoneUtils._();

  static final _mobile = RegExp(r'^01[3-9]\d{8}$');
  static final _phoneChars = RegExp(r'^[0-9০-৯+\-\s().]+$');

  /// Allows only what a phone number can contain while typing or pasting.
  static final inputFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯+\-\s().]')),
    LengthLimitingTextInputFormatter(20),
  ];

  /// Bengali digits to English: "০১৭" -> "017".
  static String toEnglishDigits(String value) => value.replaceAllMapped(
        RegExp('[০-৯]'),
        (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0x09E6 + 0x30),
      );

  /// Only the digits, Bengali digits converted.
  static String digitsOf(String? value) =>
      toEnglishDigits(value ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  /// Any common way of writing a Bangladeshi mobile number -> "01712345678":
  /// "+880 1712-345678", "(+88) 01712 345678", "008801712345678", "+88 1712345678",
  /// "1712345678", "০১৭১২-৩৪৫৬৭৮".
  /// Returns the bare digits when the number is not a Bangladeshi mobile number.
  static String? normalize(String? value) {
    var digits = digitsOf(value);
    if (digits.isEmpty) return null;
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('880')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('88') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    }
    if (digits.length == 10 && digits.startsWith('1')) digits = '0$digits';
    return digits;
  }

  static bool isValid(String? value) => _mobile.hasMatch(normalize(value) ?? '');

  /// "8801712345678" for SMS gateways and WhatsApp; null when not a valid mobile number.
  static String? international(String? value) =>
      isValid(value) ? '88${normalize(value)}' : null;

  /// What to hand to the dialer or SMS app: the clean local number when valid,
  /// otherwise the digits as written.
  static String dialable(String value) =>
      isValid(value) ? normalize(value)! : toEnglishDigits(value).replaceAll(RegExp(r'[^0-9+]'), '');

  /// Digits to look for when a search box holds (part of) a phone number, else null.
  static String? searchKey(String query) =>
      _phoneChars.hasMatch(query.trim()) ? normalize(query) : null;

  /// Error text for an optional phone field, or null when it is empty or valid.
  static String? validate(String? value) {
    if (normalize(value) == null) return null;
    return isValid(value) ? null : 'সঠিক মোবাইল নম্বর দিন (যেমন 01712345678)';
  }
}
