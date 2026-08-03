import 'package:feature_auth/src/l10n/generated/auth_l10n.dart';
import 'package:flutter/widgets.dart';

/// This feature's copy: `context.authL10n.loginSubmit`.
///
/// Named `authL10n` rather than a bare `l10n` so that a screen reaching for a
/// shared string — "Cancel", "Try again" — has to write `context.coreL10n` and
/// notice it is borrowing from `core_ui`. One `l10n` per package would collide
/// the moment a file imports two of them, and the collision would be resolved by
/// an import alias rather than by anybody thinking about where the string
/// belongs.
///
/// Borrowing downward is fine and needs no new rule: reading `CoreL10n` from
/// here requires importing `package:core_ui`, which `make check-deps` already
/// arbitrates. The reverse — `core_ui` reading `AuthL10n` — fails that check for
/// the same reason.
extension AuthL10nX on BuildContext {
  AuthL10n get authL10n => AuthL10n.of(this);
}
