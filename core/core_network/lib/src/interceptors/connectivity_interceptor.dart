import 'package:core_kit/core_kit.dart';
import 'package:dio/dio.dart';

/// Feeds real traffic back into [ConnectivityMonitor].
///
/// This is what makes the connectivity banner accurate without polling. The OS
/// interface stream says an interface exists; only an actual request proves the
/// backend is reachable. Every response the app already makes is a free probe,
/// so in normal use the monitor never has to send one of its own.
final class ConnectivityInterceptor extends Interceptor {
  const ConnectivityInterceptor(this._monitor);

  final ConnectivityMonitor _monitor;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _monitor.reportReachable();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        _monitor.reportUnreachable();

      case DioExceptionType.badResponse:
        // The server answered — 500 included. That is proof the network works,
        // and treating it as offline would put a "no connection" banner over a
        // backend outage and send everyone to check their wifi.
        _monitor.reportReachable();

      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        // Ambiguous: a slow upload, a proxy, or a cancelled request says
        // nothing certain about connectivity. Report nothing rather than guess.
        break;
    }
    handler.next(err);
  }
}
