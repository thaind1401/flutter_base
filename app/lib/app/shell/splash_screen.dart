import 'package:core_arch/core_arch.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Shown only if a redirect has not resolved yet.
///
/// Session restore happens in bootstrap, *before* `runApp`, so in practice this
/// is a single frame. Doing the restore here instead would make every cold
/// start flash the login screen for signed-in users.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const RouteSpec spec = RouteSpec(name: 'splash', path: '/');

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: context.colors.background, body: const AppLoader());
  }
}
