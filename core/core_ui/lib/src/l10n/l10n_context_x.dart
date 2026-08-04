import 'package:core_ui/src/l10n/generated/core_l10n.dart';
import 'package:flutter/widgets.dart';

/// The design system's shared copy: `context.coreL10n.commonCancel`.
///
/// This is the one every other package is allowed to borrow, and the only l10n
/// a `core_*` package may use. Anything a feature needs that is not generic
/// chrome — "Sign in", "Welcome back" — belongs in that feature's own ARB, not
/// here; `core_ui` knows nothing about the app's domain and its ARB must stay
/// that way. ADR-0011.
extension CoreL10nX on BuildContext {
  CoreL10n get coreL10n => CoreL10n.of(this);
}
