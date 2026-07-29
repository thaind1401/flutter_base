import 'package:core_kit/core_kit.dart';
import 'package:test/test.dart';

void main() {
  group('LogRedactor', () {
    test('masks bearer tokens in headers', () {
      final out = LogRedactor.redact('Authorization: Bearer abc.def123-ghi');
      expect(out, isNot(contains('abc.def123-ghi')));
      expect(out, contains(LogRedactor.mask));
    });

    test('masks a JWT anywhere in the line', () {
      const jwt = 'eyJhbGciOi.eyJzdWIiOjEyMw.SflKxwRJSM';
      expect(LogRedactor.redact('token=$jwt sent'), isNot(contains(jwt)));
    });

    test('masks sensitive JSON values but keeps the key', () {
      final out = LogRedactor.redact('{"username":"john","password":"hunter2"}');
      expect(out, contains('"password"'));
      expect(out, isNot(contains('hunter2')));
      expect(out, contains('john'));
    });

    test('masks sensitive query parameters', () {
      final out = LogRedactor.redact('https://api.test/login?client_secret=s3cr3t&lang=vi');
      expect(out, isNot(contains('s3cr3t')));
      expect(out, contains('lang=vi'));
    });

    test('partially masks emails so lines stay correlatable', () {
      expect(LogRedactor.redact('user john.doe@corp.com failed'), contains('j***@corp.com'));
    });

    test('masks long digit runs that could be card or id numbers', () {
      expect(LogRedactor.redact('card 4111111111111111'), isNot(contains('4111111111111111')));
    });

    test('redactValue walks nested structures', () {
      final out = LogRedactor.redactValue({
        'user': {'name': 'A', 'accessToken': 'xyz'},
        'items': [
          {'refresh_token': 'abc'},
        ],
      });
      expect(out.toString(), isNot(contains('xyz')));
      expect(out.toString(), isNot(contains('abc')));
      expect(out.toString(), contains('A'));
    });

    test('leaves harmless text untouched', () {
      const input = 'GET /v1/profile 200 in 34ms';
      expect(LogRedactor.redact(input), input);
    });
  });
}
