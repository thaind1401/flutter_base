import 'dart:async';

import 'package:app/app/app.dart';
import 'package:app/app/bootstrap.dart';
import 'package:app/app/di/console_logger.dart';
import 'package:app/app/di/injection.dart';
import 'package:app/app/error/boot_failure_app.dart';
import 'package:app/app/error/global_error_handler.dart';
import 'package:core_kit/core_kit.dart';
import 'package:flutter/material.dart';

Future<void> main() => _start();

Future<void> _start() async {
  // Before the container, before anything that can throw. An error raised while
  // composing dependencies is the one this most needs to catch, and installing
  // after `Bootstrap.run()` would miss exactly that.
  WidgetsFlutterBinding.ensureInitialized();
  GlobalErrorHandler.install(_logger);

  final BootstrapResult bootstrap;
  try {
    bootstrap = await Bootstrap.run();
  } catch (error, stackTrace) {
    // `runApp` has not been called yet, so there is no widget tree to fail
    // gracefully inside — without this the process holds the launch image and
    // shows nothing, forever, on this launch and every one after it.
    _logger().error('bootstrap failed; the app cannot open', tag: 'startup', error: error, stackTrace: stackTrace);
    runApp(const BootFailureApp(onRetry: _restart));
    return;
  }

  runApp(App(bootstrap: bootstrap));

  // After the first frame, never before: this is where analytics, push and
  // remote config go, and blocking startup on them is how cold start rots.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(Bootstrap.runDeferredStartup());
  });
}

/// A second start attempt, from an empty container.
///
/// The reset is not optional. A bootstrap that threw part-way through
/// `configureDependencies()` leaves `getIt` holding whatever registered before
/// the failure, and `init()` over a populated container throws on the first
/// duplicate — so a retry without this reports a registration error instead of
/// the real fault, every time.
Future<void> _restart() async {
  await getIt.reset();
  await _start();
}

/// The logger the crash hooks report through.
///
/// A supplier rather than an instance because the hooks outlive any single
/// container: they are installed before `configureDependencies()` and survive
/// the reset in [_restart]. `ConsoleLogger` covers the window where the real one
/// is not registered — which is precisely when startup is failing.
AppLogger _logger() => getIt.isRegistered<AppLogger>() ? getIt<AppLogger>() : const ConsoleLogger();
