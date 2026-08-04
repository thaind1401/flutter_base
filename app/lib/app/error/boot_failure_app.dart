import 'package:app/app/l10n/app_localizations.dart';
import 'package:app/app/l10n/generated/app_l10n.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// What the user sees when `Bootstrap.run()` throws.
///
/// Without it, that case is a black screen forever: `main` propagates, `runApp`
/// is never reached, the engine holds the launch image and the process sits
/// there. There is no error, no message and no way out but force-quitting —
/// and force-quitting changes nothing, because the next launch takes the same
/// path.
///
/// It is not a hypothetical. Bootstrap reads the keychain and shared
/// preferences, and iOS refuses keychain access before the device's first
/// unlock after a reboot, so a push-launched cold start can fail there. A DI
/// registration that only breaks on a real device does the same, and
/// `app_smoke_test.dart` cannot see it — it mocks all three platform channels.
///
/// This deliberately depends on nothing the container provides. `AppTheme` and
/// [AppLocalizationsSetup] are both plain statics, so this renders whether or
/// not `configureDependencies()` got anywhere.
class BootFailureApp extends StatefulWidget {
  const BootFailureApp({super.key, required this.onRetry});

  /// Runs a second start attempt. Completes when it fails; on success it has
  /// already called `runApp` with the real app and this widget is gone.
  final Future<void> Function() onRetry;

  @override
  State<BootFailureApp> createState() => _BootFailureAppState();
}

class _BootFailureAppState extends State<BootFailureApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await widget.onRetry();
    // Only reached when the retry failed too — a successful one replaced the
    // root widget with `App` and unmounted this.
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // The stored theme lives behind `ThemeModeController`, which is exactly
      // what may have failed to resolve. Following the platform costs nothing
      // and cannot throw.
      themeMode: ThemeMode.system,
      // No mini-app delegates: the registry is built inside the bootstrap that
      // just failed. These are the compile-time ones and they need no container.
      localizationsDelegates: AppLocalizationsSetup.delegates,
      supportedLocales: AppLocalizationsSetup.supportedLocales,
      home: _BootFailureScreen(isRetrying: _retrying, onRetry: _retry),
    );
  }
}

/// A `BaseScreen` like every other screen (rule 10), and stateless: the retry
/// flag is owned above so this stays a plain rebuild on a value it is handed.
class _BootFailureScreen extends BaseScreen {
  const _BootFailureScreen({required this.isRetrying, required this.onRetry});

  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget buildBody(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.dimens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: context.colors.textDisabled),
            SizedBox(height: context.dimens.space12),
            // `header: true` so a screen reader's heading navigation lands on
            // the one thing that matters, as `AppErrorView` does.
            Semantics(
              header: true,
              child: Text(l10n.bootFailureTitle, textAlign: TextAlign.center, style: context.textStyles.titleSm),
            ),
            SizedBox(height: context.dimens.space4),
            Text(
              l10n.bootFailureMessage,
              textAlign: TextAlign.center,
              style: context.textStyles.bodySm.copyWith(color: context.colors.textSecondary),
            ),
            SizedBox(height: context.dimens.space24),
            // The core package owns "Try again" — the app reading a core
            // package's copy is the direction rule 15 allows.
            AppButton(
              label: CoreL10n.of(context).commonRetry,
              isLoading: isRetrying,
              expanded: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
