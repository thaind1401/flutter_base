/// Test-only transport stubs.
///
/// A separate entry point from `core_network.dart`, and that separation is the
/// point. The main barrel deliberately exports only the slice of Dio a data
/// source legitimately needs and keeps adapters inside this package, because a
/// feature reaching for `HttpClientAdapter` in production code is a feature
/// doing transport work it has no business doing.
///
/// But the same rule left every feature unable to test its data layer without a
/// socket: `feature_auth`'s repository and refresh API both sat at 0% coverage
/// for exactly this reason. The seam belongs here, once, rather than in each
/// feature's pubspec as a direct `dio` dependency that quietly re-opens the
/// boundary for production code too.
///
/// ```dart
/// import 'package:core_network/testing.dart';
///
/// final adapter = StubHttpAdapter.json({'/auth/login': jsonResponse(body)});
/// final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
///   ..httpClientAdapter = adapter;
/// ```
library core_network.testing;

import 'package:dio/dio.dart';

export 'package:dio/dio.dart' show HttpClientAdapter, ResponseBody;

/// A JSON response body with the content type set, which `Dio` needs in order
/// to decode it into a `Map` rather than handing back a raw `String`.
ResponseBody jsonResponse(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// Serves canned outcomes per request path, and records what was asked.
///
/// An outcome is either a [ResponseBody] to return or an [Object] to throw —
/// usually a `DioException`, so a test can exercise the transport-failure path
/// as easily as the success one.
final class StubHttpAdapter implements HttpClientAdapter {
  /// One outcome for every request, whatever the path.
  StubHttpAdapter.always(Object outcome) : _byPath = const {}, _fallback = outcome;

  /// Outcomes keyed by request path. A path with no entry falls back to
  /// [orElse]; without one, an unexpected path fails the test loudly rather
  /// than returning an empty 200 that makes the assertion pass for the wrong
  /// reason.
  StubHttpAdapter.paths(Map<String, Object> outcomes, {Object? orElse}) : _byPath = outcomes, _fallback = orElse;

  final Map<String, Object> _byPath;
  final Object? _fallback;

  /// Every request seen, in order. Assert on this rather than on a call count
  /// when the question is "did it send the right thing?".
  final List<RequestOptions> requests = [];

  /// How many times [path] was requested. Used to prove a call did *not*
  /// happen — a refresh that should have been skipped, a retry that should
  /// have stopped.
  int callsTo(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);

    final outcome = _byPath[options.path] ?? _fallback;
    if (outcome == null) {
      return Future.error(
        StateError(
          'StubHttpAdapter has no outcome for "${options.path}". '
          'Add it to StubHttpAdapter.paths, or pass orElse.',
        ),
      );
    }
    if (outcome is ResponseBody) return Future.value(outcome);
    return Future.error(outcome);
  }

  @override
  void close({bool force = false}) {}
}
