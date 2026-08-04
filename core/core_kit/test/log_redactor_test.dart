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

  group('payloads that used to walk straight through', () {
    // Every case here leaked when this redactor was probed with realistic log
    // lines rather than with the strings it had been written against. The suite
    // above was green throughout — it tested the formats the author had in mind.
    //
    // The one worth remembering is the Dart map: `password` was already in
    // `sensitiveKeys`, and `logger.debug('body: $map')` is the most natural line
    // anyone writes, and it printed the password in full. That is not the
    // documented limitation about unanticipated field names — it is an
    // anticipated key going through in the commonest format there is.

    void expectRedacted(String input, {required String secret}) {
      final out = LogRedactor.redact(input);
      expect(out, isNot(contains(secret)), reason: 'leaked from: $input\ngot: $out');
      expect(out, contains(LogRedactor.mask), reason: 'nothing was masked in: $input');
    }

    test('a Dart map printed by string interpolation', () {
      expectRedacted('{password: hunter2, email: a@b.com}', secret: 'hunter2');
    });

    test('an Authorization header that is not Bearer', () {
      // The scheme sits between the key and the secret, so a pattern that stops
      // at the first space keeps `Basic` and hands over the credentials.
      expectRedacted('Authorization: Basic dXNlcjpwYXNzd29yZA==', secret: 'dXNlcjpwYXNzd29yZA==');
    });

    test('session cookies, sent and received', () {
      expectRedacted('Cookie: session=9f8a7b6c5d4e3f2a1b0c', secret: '9f8a7b6c5d4e3f2a1b0c');
      expectRedacted('set-cookie: sid=abc123def456; HttpOnly', secret: 'abc123def456');
    });

    test('an API key sent as a header rather than a body field', () {
      expectRedacted('x-api-key: sk_live_abcdef123456', secret: 'sk_live_abcdef123456');
    });

    test('key names that were simply missing from the list', () {
      expectRedacted('{"authToken": "leak-me"}', secret: 'leak-me');
      expectRedacted('{"sessionId": "sess_abc"}', secret: 'sess_abc');
      expectRedacted('{"passwd": "hunter2"}', secret: 'hunter2');
      expectRedacted('{"privateKey": "-----BEGIN RSA-----"}', secret: 'BEGIN RSA');
    });

    test('a card number written the way it is printed on the card', () {
      expectRedacted('card 4111 1111 1111 1111', secret: '4111 1111 1111 1111');
    });

    test('masking a query parameter keeps it a query string', () {
      // The first fix rewrote every match as `key: value`, which redacted the
      // token correctly and turned the URL into something that no longer parsed
      // as one. A log nobody can read is a log nobody checks.
      final out = LogRedactor.redact('https://api.x.com/v1?token=abc123&page=2');

      expect(out, isNot(contains('abc123')));
      expect(out, contains('token=${LogRedactor.mask}'));
      expect(out, contains('&page=2'), reason: 'the rest of the query was damaged: $out');
    });

    test('ordinary logs are still readable', () {
      // The counterweight. Over-redaction is cheap to add and turns the log into
      // a wall of asterisks, at which point people stop reading it and the
      // redactor has cost more than it saved.
      const plain = 'user opened the settings screen';
      expect(LogRedactor.redact(plain), plain);
      expect(LogRedactor.redact('{"page": 2, "total": 40}'), '{"page": 2, "total": 40}');
      expect(LogRedactor.redact('GET /v1/orders?status=open&page=3'), 'GET /v1/orders?status=open&page=3');
    });
  });
}
