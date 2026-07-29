import 'dart:async';

import 'package:app/app/app.dart';
import 'package:app/app/bootstrap.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  final result = await Bootstrap.run();

  runApp(App(bootstrap: result));

  // After the first frame, never before: this is where analytics, push and
  // remote config go, and blocking startup on them is how cold start rots.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(Bootstrap.runDeferredStartup());
  });
}
