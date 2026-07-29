import 'dart:async';

import 'package:core_kit/core_kit.dart';
import 'package:meta/meta.dart';

/// The boundary where transport exceptions stop and [Result] begins.
///
/// Every data-source call goes through [guard]. Above this line nothing throws;
/// below it, Dio, plugins and JSON decoding throw as they please. Concentrating
/// the conversion here is what lets use cases and blocs contain no `try/catch`
/// at all.
///
/// ```dart
/// @LazySingleton(as: ProfileRepository)
/// final class ProfileRepositoryImpl extends BaseRepository implements ProfileRepository {
///   ProfileRepositoryImpl(this._api, super.failureMapper);
///   final ProfileApi _api;
///
///   @override
///   Future<Result<Profile>> fetch(String id) =>
///       guard(() async => (await _api.getProfile(id)).toEntity());
/// }
/// ```
abstract base class BaseRepository {
  const BaseRepository(this.failureMapper);

  /// Injected rather than inherited so the transport can be swapped (Dio today,
  /// gRPC tomorrow) without every repository changing its supertype.
  @protected
  final FailureMapper failureMapper;

  /// Runs [body], converting anything it throws into a [Failure].
  @protected
  Future<Result<T>> guard<T>(FutureOr<T> Function() body) => Result.guardAsync(body, onError: failureMapper.map);

  /// [guard] plus a local fallback.
  ///
  /// For reads that should degrade rather than fail: try the network, and on a
  /// *transport* failure fall back to cache. Business and auth failures are
  /// deliberately not swallowed — a 401 or a rejected rule must reach the UI.
  @protected
  Future<Result<T>> guardWithFallback<T>(
    FutureOr<T> Function() body, {
    required FutureOr<Result<T>> Function(Failure failure) fallback,
    bool Function(Failure failure)? shouldFallback,
  }) async {
    final result = await guard(body);
    if (result case Err<T>(:final failure)) {
      final canFallback = shouldFallback?.call(failure) ?? failure.isRetryable;
      if (canFallback) return fallback(failure);
    }
    return result;
  }

  /// Reads through a cache: returns the cached value when present, otherwise
  /// fetches, stores and returns. [write] failures are ignored on purpose — a
  /// full disk must not turn a successful fetch into an error.
  @protected
  Future<Result<T>> cacheThrough<T>({
    required Future<Result<T?>> Function() read,
    required FutureOr<T> Function() fetch,
    required Future<Result<Unit>> Function(T value) write,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await read();
      if (cached case Ok<T?>(:final value) when value != null) return Ok<T>(value);
    }
    final fresh = await guard(fetch);
    if (fresh case Ok<T>(:final value)) unawaited(write(value));
    return fresh;
  }
}
