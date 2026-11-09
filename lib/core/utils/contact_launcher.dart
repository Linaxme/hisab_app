import 'package:url_launcher/url_launcher.dart';
import 'phone_utils.dart';

/// Opens WhatsApp, SMS and the dialer for Bangladeshi phone numbers.
class ContactLauncher {
  ContactLauncher._();

  static Future<bool> whatsApp({String? phone, required String text}) {
    final number = PhoneUtils.international(phone) ?? PhoneUtils.digitsOf(phone);
    return _open(Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}'));
  }

  static Future<bool> sms({required String phone, required String text}) {
    final number = PhoneUtils.dialable(phone);
    return _open(Uri.parse('sms:$number?body=${Uri.encodeComponent(text)}'));
  }

  static Future<bool> call(String phone) {
    return _open(Uri(scheme: 'tel', path: PhoneUtils.dialable(phone)));
  }

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
