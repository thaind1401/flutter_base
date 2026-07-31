import 'package:core_kit/core_kit.dart';
import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// The interceptor that prints request bodies, which is to say the one place
/// most likely to write a password into a log.
///
/// Its own doc comment claims two guarantees — every line goes through
/// `LogRedactor`, and the interceptor is only installed when the config asks
/// for it — and neither had a test. Redaction failing open is silent by
/// definition: the log looks fine to whoever reads it, and the token is in it.
/// Answers every request with one canned outcome: a [ResponseBody] to return,
/// or a [DioException] to throw. Enough to drive the interceptor through a real
/// `Dio` without a socket.
final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.outcome);

  final Object outcome;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    if (outcome is ResponseBody) return Future.value(outcome as ResponseBody);
    return Future.error(outcome);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late InMemoryLogger logger;
  late LoggingInterceptor interceptor;

  setUp(() {
    logger = InMemoryLogger();
    interceptor = LoggingInterceptor(logger: logger);
  });

  String lastMessage() => logger.records.last.message;

  RequestOptions request({
    String method = 'GET',
    String path = '/things',
    Object? data,
    Map<String, Object?>? headers,
  }) => RequestOptions(
    path: path,
    method: method,
    baseUrl: 'https://api.example.com',
    data: data,
    headers: headers ?? {},
  );

  group('requests', () {
    test('are logged as a runnable cURL', () {
      // The format is the point: a line someone can paste into a terminal to
      // reproduce a failure, rather than a pretty-printed blob they cannot.
      interceptor.onRequest(request(), RequestInterceptorHandler());

      expect(lastMessage(), contains('curl -X GET'));
      expect(lastMessage(), contains('https://api.example.com/things'));
      expect(lastMessage(), contains('[http]'));
    });

    test('headers are included, except the one that would break the paste', () {
      interceptor.onRequest(
        request(headers: {'X-App-Version': '1.2.3', 'content-length': '42'}),
        RequestInterceptorHandler(),
      );

      expect(lastMessage(), contains("-H 'X-App-Version: 1.2.3'"));
      // curl computes content-length itself; echoing the original makes the
      // pasted command fail if the body was edited at all.
      expect(lastMessage(), isNot(contains('content-length')));
    });

    test('a body is attached for a POST but not for a GET', () {
      interceptor.onRequest(request(method: 'POST', data: {'name': 'value'}), RequestInterceptorHandler());
      expect(lastMessage(), contains('--data'));

      interceptor.onRequest(request(data: {'name': 'value'}), RequestInterceptorHandler());
      expect(lastMessage(), isNot(contains('--data')));
    });

    test('a credential in the body is redacted', () {
      // The failure that matters. `LogRedactor` has its own tests for the
      // patterns; this asserts the interceptor actually routes through it.
      interceptor.onRequest(
        request(method: 'POST', path: '/auth/login', data: {'email': 'user@example.com', 'password': 'hunter2'}),
        RequestInterceptorHandler(),
      );

      expect(lastMessage(), isNot(contains('hunter2')));
      expect(lastMessage(), isNot(contains('user@example.com')));
    });

    test('an Authorization header is redacted', () {
      interceptor.onRequest(
        request(headers: {'Authorization': 'Bearer abcdef1234567890'}),
        RequestInterceptorHandler(),
      );

      expect(lastMessage(), isNot(contains('abcdef1234567890')));
    });

    test('a FormData body is summarised rather than serialised', () {
      // `jsonEncode` on a `FormData` throws, and an upload's bytes have no
      // business in a log even if it did not.
      final form = FormData.fromMap({'title': 'photo', 'file': MultipartFile.fromString('x' * 100)});

      interceptor.onRequest(request(method: 'POST', data: form), RequestInterceptorHandler());

      expect(lastMessage(), contains('title'));
      expect(lastMessage(), contains('files'));
    });
  });

  group('responses', () {
    Response<dynamic> response(int status, Object? data) =>
        Response<dynamic>(requestOptions: request(), statusCode: status, data: data);

    test('are logged with status, method and elapsed time', () {
      final options = request();
      interceptor.onRequest(options, RequestInterceptorHandler());
      interceptor.onResponse(
        Response<dynamic>(requestOptions: options, statusCode: 200, data: {'ok': true}),
        ResponseInterceptorHandler(),
      );

      expect(lastMessage(), contains('← 200 GET'));
      expect(lastMessage(), matches(RegExp(r'\(\d+ms\)')));
    });

    test('elapsed time degrades to a marker when the request was not seen', () {
      // Happens whenever the interceptor is added mid-flight or a replay skips
      // `onRequest`. It must not crash the logging path.
      interceptor.onResponse(response(200, null), ResponseInterceptorHandler());

      expect(lastMessage(), contains('?ms'));
    });

    test('the body is omitted when logResponseBody is off', () {
      final quiet = LoggingInterceptor(logger: logger, logResponseBody: false);

      quiet.onResponse(response(200, {'secret': 'value'}), ResponseInterceptorHandler());

      expect(lastMessage(), isNot(contains('secret')));
    });

    test('a long body is truncated with its real length reported', () {
      // A 2 MB list response otherwise scrolls everything else out of the
      // console and stalls the app while it is being formatted.
      final small = LoggingInterceptor(logger: logger, maxBodyChars: 20);

      small.onResponse(response(200, {'items': List.filled(200, 'value')}), ResponseInterceptorHandler());

      expect(lastMessage(), contains('…'));
      expect(lastMessage(), contains('chars)'));
    });

    test('personal data in a response body is redacted', () {
      interceptor.onResponse(response(200, {'email': 'someone@example.com'}), ResponseInterceptorHandler());

      expect(lastMessage(), isNot(contains('someone@example.com')));
    });
  });

  // The error path is driven through a real `Dio` rather than by calling
  // `onError` directly. `ErrorInterceptorHandler.next` rejects the handler's
  // future — that is how it passes the error down the chain — and the future is
  // not reachable from outside the package, so a hand-driven call leaves an
  // unhandled async error that fails the test for a reason unrelated to the
  // assertion. Going through Dio also exercises the interceptor the way it is
  // actually installed, request and error together.
  group('errors', () {
    Dio clientReturning(Object failure) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = _StubAdapter(failure)
        ..interceptors.add(LoggingInterceptor(logger: logger));
      return dio;
    }

    test('are logged at error level with the status', () async {
      final dio = clientReturning(ResponseBody.fromString('{"message":"boom"}', 500));

      await expectLater(dio.get<dynamic>('/things'), throwsA(isA<DioException>()));

      expect(logger.records.last.level, LogLevel.error);
      expect(lastMessage(), contains('✖ 500 GET'));
    });

    test('a transport failure with no response logs its type instead', () async {
      // No status to print, so the exception type is what tells whoever reads
      // the log whether this was DNS, a refused socket or a timeout.
      final dio = clientReturning(
        DioException(
          requestOptions: RequestOptions(path: '/things'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(dio.get<dynamic>('/things'), throwsA(isA<DioException>()));

      expect(lastMessage(), contains('connectionError'));
    });

    test('an error body is redacted like any other', () async {
      final dio = clientReturning(ResponseBody.fromString('{"email":"someone@example.com"}', 422));

      await expectLater(dio.get<dynamic>('/things'), throwsA(isA<DioException>()));

      expect(lastMessage(), isNot(contains('someone@example.com')));
    });
  });

  test('nothing is logged below the logger minimum level', () {
    // How a production build stays silent even if the interceptor is installed
    // by mistake: request/response go out at debug, and prod runs at warning.
    final quiet = InMemoryLogger(minimumLevel: LogLevel.warning);
    final production = LoggingInterceptor(logger: quiet);

    production.onRequest(request(), RequestInterceptorHandler());
    production.onResponse(
      Response<dynamic>(requestOptions: request(), statusCode: 200, data: {'x': 1}),
      ResponseInterceptorHandler(),
    );

    expect(quiet.records, isEmpty);
  });
}
