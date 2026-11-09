import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_apps/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils.normalize', () {
    test('accepts common Bangladeshi formats', () {
      expect(PhoneUtils.normalize('01712345678'), '01712345678');
      expect(PhoneUtils.normalize('01712-345678'), '01712345678');
      expect(PhoneUtils.normalize('+880 1712 345678'), '01712345678');
      expect(PhoneUtils.normalize('8801712345678'), '01712345678');
      expect(PhoneUtils.normalize('1712345678'), '01712345678');
      expect(PhoneUtils.normalize('০১৭১২৩৪৫৬৭৮'), '01712345678');
      expect(PhoneUtils.normalize('০১৭১২-৩৪৫ ৬৭৮'), '01712345678');
      expect(PhoneUtils.normalize('(+88) 01712 345678'), '01712345678');
      expect(PhoneUtils.normalize('+88 1712345678'), '01712345678');
      expect(PhoneUtils.normalize('008801712345678'), '01712345678');
      expect(PhoneUtils.normalize('0171.234.5678'), '01712345678');
    });

    test('empty input is null', () {
      expect(PhoneUtils.normalize(null), isNull);
      expect(PhoneUtils.normalize('  - '), isNull);
    });
  });

  group('PhoneUtils.validate', () {
    test('empty is allowed', () => expect(PhoneUtils.validate(''), isNull));
    test('valid mobile passes', () => expect(PhoneUtils.validate('০১৯১১-২২৩৩৪৪'), isNull));
    test('too short fails', () => expect(PhoneUtils.validate('0171234'), isNotNull));
    test('too long fails', () => expect(PhoneUtils.validate('017123456789'), isNotNull));
    test('wrong operator prefix fails', () => expect(PhoneUtils.validate('01212345678'), isNotNull));
  });

  group('PhoneUtils for SMS and calls', () {
    test('dialable is the clean local number', () {
      expect(PhoneUtils.dialable('+880 1712-345678'), '01712345678');
      expect(PhoneUtils.dialable('০১৭১২ ৩৪৫৬৭৮'), '01712345678');
    });
    test('international form for gateways and WhatsApp', () {
      expect(PhoneUtils.international('01712-345678'), '8801712345678');
      expect(PhoneUtils.international('017123'), isNull);
    });
  });

  group('PhoneUtils.searchKey', () {
    test('digits only queries search phones', () {
      expect(PhoneUtils.searchKey('1712'), '1712');
      expect(PhoneUtils.searchKey('+8801712'), '01712');
    });
    test('names do not', () => expect(PhoneUtils.searchKey('rahim 2'), isNull));
  });
}
