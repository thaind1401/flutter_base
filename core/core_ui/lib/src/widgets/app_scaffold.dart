import 'package:core_ui/src/theme/theme_context_x.dart';
import 'package:flutter/material.dart';

/// Page chrome with the defaults every screen would otherwise repeat.
///
/// What it standardises:
///   * tapping outside a field dismisses the keyboard — expected on mobile and
///     forgotten on most screens;
///   * `resizeToAvoidBottomInset` on, so a form is not covered by the keyboard;
///   * safe-area handling in one place, including the bottom action bar that
///     otherwise ends up under the home indicator on iOS.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.appBar,
    this.actions,
    this.bottomBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.padded = false,
    this.showBackButton = true,
    this.onBack,
    this.dismissKeyboardOnTap = true,
    this.safeAreaBottom = true,
  });

  final Widget body;
  final String? title;

  /// Full override. When null and [title] is set, a standard app bar is built.
  final PreferredSizeWidget? appBar;

  final List<Widget>? actions;

  /// Pinned action area, inset above the keyboard and the home indicator.
  final Widget? bottomBar;

  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool padded;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool dismissKeyboardOnTap;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: backgroundColor ?? context.colors.background,
      resizeToAvoidBottomInset: true,
      appBar: appBar ?? (title == null ? null : _buildAppBar(context)),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        bottom: safeAreaBottom,
        child: padded ? Padding(padding: context.dimens.pageInsets, child: body) : body,
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.dimens.pagePadding,
                  context.dimens.space8,
                  context.dimens.pagePadding,
                  context.dimens.space8 + context.keyboardInset,
                ),
                child: bottomBar,
              ),
            ),
    );

    if (!dismissKeyboardOnTap) return scaffold;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      // Translucent so taps still reach the scaffold's own gesture handlers.
      behavior: HitTestBehavior.translucent,
      child: scaffold,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      title: Text(title!),
      actions: actions,
      automaticallyImplyLeading: false,
      leading: (showBackButton && (canPop || onBack != null))
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
    );
  }
}
