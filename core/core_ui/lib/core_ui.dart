/// The design system: tokens, themes, localization scaffolding, shared widgets
/// and overlays.
///
/// Rule: this package knows nothing about the app's domain. It has no entities,
/// no repositories, no feature-specific widgets. A widget that mentions
/// "invoice" or "employee" belongs in that feature's package, not here.
library core_ui;

export 'di.module.dart' show CoreUiPackageModule;
export 'src/l10n/failure_presenter.dart';
export 'src/l10n/generated/core_l10n.dart';
export 'src/l10n/l10n_context_x.dart';
export 'src/overlays/app_feedback.dart';
export 'src/overlays/connectivity_banner.dart';
export 'src/overlays/loading_overlay.dart';
// The three shapes every screen extends. `_BasePagedScreen` stays private: the
// choice a screen author makes is one of these three, not four.
export 'src/screens/base_screen.dart' show BaseGridScreen, BaseListScreen, BaseScreen;
export 'src/theme/app_colors.dart';
export 'src/theme/app_dimens.dart';
export 'src/theme/app_theme.dart';
export 'src/theme/app_typography.dart';
export 'src/theme/theme_context_x.dart';
export 'src/widgets/app_button.dart';
export 'src/widgets/app_date_field.dart';
export 'src/widgets/app_dropdown_field.dart';
export 'src/widgets/app_scaffold.dart';
export 'src/widgets/app_switch_tile.dart';
export 'src/widgets/app_text_field.dart';
export 'src/widgets/bloc_effect_listener.dart';
export 'src/widgets/paged_grid_view.dart';
export 'src/widgets/paged_list_view.dart';
export 'src/widgets/paged_scroll_view.dart';
export 'src/widgets/state_views.dart';
export 'src/widgets/view_state_builder.dart';
