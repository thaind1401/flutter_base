import 'dart:async';

import 'package:app/app/session/session_cubit.dart';
import 'package:app/app/theme/theme_mode_controller.dart';
import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends BaseScreen {
  const SettingsScreen({super.key, required this.themeMode});

  static const RouteSpec spec = RouteSpec(name: 'settings', path: '/settings');

  final ThemeModeController themeMode;

  @override
  String? title(BuildContext context) => 'Settings';

  @override
  bool get padded => true;

  @override
  Widget buildBody(BuildContext context) {
    return ListView(
      children: [
        Text('Appearance', style: context.textStyles.titleSm),
        SizedBox(height: context.dimens.space8),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeMode,
          builder: (context, mode, _) => SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {mode},
            // Fire-and-forget: `select` applies the mode synchronously and only
            // the persistence is awaited, so there is nothing for the UI to
            // wait on and nothing it could do about a failed write.
            onSelectionChanged: (selection) => unawaited(themeMode.select(selection.first)),
          ),
        ),
        SizedBox(height: context.dimens.space32),
        AppButton.danger(
          label: 'Sign out',
          icon: Icons.logout_rounded,
          onPressed: () async {
            final confirmed = await context.confirm(
              title: 'Sign out?',
              message: 'You will need to sign in again to continue.',
              confirmLabel: 'Sign out',
              isDestructive: true,
            );
            // The dialog awaited across a frame; the screen may be gone.
            if (!confirmed || !context.mounted) return;
            await context.read<SessionCubit>().signOut();
          },
        ),
        SizedBox(height: context.dimens.space24),
        const _EnvironmentBanner(),
      ],
    );
  }
}

/// Shows which flavor the build is. Cheap, and it has saved more than one
/// "why is staging data in production?" investigation.
class _EnvironmentBanner extends StatelessWidget {
  const _EnvironmentBanner();

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppEnvironmentConfig>();
    if (config.isProduction) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(context.dimens.space12),
      decoration: BoxDecoration(color: context.colors.surfaceVariant, borderRadius: context.dimens.radiusMdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Environment: ${config.environment.name}', style: context.textStyles.label),
          Text(config.baseUrl, style: context.textStyles.caption.copyWith(color: context.colors.textSecondary)),
        ],
      ),
    );
  }
}
