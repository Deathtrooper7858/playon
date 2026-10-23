import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playon/services/cookie_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CookieService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getCookies returns null when nothing is stored', () async {
      final cookies = await CookieService.getCookies();
      expect(cookies, isNull);
    });

    test('saveCookies and getCookies roundtrip correctly', () async {
      const sample = 'LOGIN_INFO=abc123xyz; SID=secret456';
      await CookieService.saveCookies(sample);
      final retrieved = await CookieService.getCookies();
      expect(retrieved, sample);
    });

    test('clearCookies removes stored cookies', () async {
      await CookieService.saveCookies('TEST=123');
      expect(await CookieService.getCookies(), 'TEST=123');
      await CookieService.clearCookies();
      expect(await CookieService.getCookies(), isNull);
    });

    test('hasValidSession identifies valid auth cookies', () {
      expect(CookieService.hasValidSession(null), isFalse);
      expect(CookieService.hasValidSession(''), isFalse);
      expect(CookieService.hasValidSession('theme=dark; lang=es'), isFalse);
      expect(CookieService.hasValidSession('LOGIN_INFO=token123'), isTrue);
      expect(CookieService.hasValidSession('SAPISID=sec; HSID=abc'), isTrue);
      expect(CookieService.hasValidSession('__Secure-3PSID=token'), isTrue);
      expect(CookieService.hasValidSession('VISITOR_INFO1_LIVE=xyz'), isTrue);
    });

    test('parseCookies correctly extracts key-value map', () {
      const header = 'SID=abc; HSID=def; SSID=ghi; empty=; invalid_no_equals';
      final parsed = CookieService.parseCookies(header);

      expect(parsed['SID'], 'abc');
      expect(parsed['HSID'], 'def');
      expect(parsed['SSID'], 'ghi');
      expect(parsed['empty'], '');
      expect(parsed.containsKey('invalid_no_equals'), isFalse);
    });

    test('mergeCookieMaps combines and dedupes multiple cookie maps', () {
      final map1 = {'SID': 'old_sid', 'PREF': 'f1=50000000'};
      final map2 = {'SID': 'new_sid', 'LOGIN_INFO': 'token_login'};

      final merged = CookieService.mergeCookieMaps([map1, map2]);
      expect(merged, contains('SID=new_sid'));
      expect(merged, contains('PREF=f1=50000000'));
      expect(merged, contains('LOGIN_INFO=token_login'));
    });
  });
}
