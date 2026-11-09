import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp, SMS and the dialer for Bangladeshi phone numbers.
class ContactLauncher {
  ContactLauncher._();

  /// Digits only, in international form: "01712-345678" -> "8801712345678".
  static String? internationalBd(String? phone) {
    final digits = phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (digits.isEmpty) return null;
    if (digits.startsWith('880')) return digits;
    if (digits.startsWith('0')) return '88$digits';
    if (digits.length == 10 && digits.startsWith('1')) return '880$digits';
    return digits;
  }

  static Future<bool> whatsApp({String? phone, required String text}) {
    final number = internationalBd(phone) ?? '';
    return _open(Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}'));
  }

  static Future<bool> sms({required String phone, required String text}) {
    final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return _open(Uri.parse('sms:$number?body=${Uri.encodeComponent(text)}'));
  }

  static Future<bool> call(String phone) {
    final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return _open(Uri(scheme: 'tel', path: number));
  }

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
