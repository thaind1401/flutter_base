import 'package:app/app/session/session_cubit.dart';
import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_contract/mini_app_contract.dart';

/// Host home screen.
///
/// Its only interesting job is rendering the installed mini-apps. Note that it
/// reads them from [MiniAppRegistry] and never imports a mini-app package —
/// adding one changes the DI list, not this file.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.registry});

  static const RouteSpec spec = RouteSpec(name: 'home', path: '/home');

  final MiniAppRegistry registry;

  @override
  Widget build(BuildContext context) {
    final entries = registry.entryPointsFor(context, MiniAppPlacement.home);

    return AppScaffold(
      title: 'Home',
      padded: true,
      body: ListView(
        children: [
          const _UserCard(),
          SizedBox(height: context.dimens.space24),
          if (entries.isNotEmpty) ...[
            Text('Apps', style: context.textStyles.titleSm),
            SizedBox(height: context.dimens.space12),
            for (final entry in entries) ...[_MiniAppTile(entry: entry), SizedBox(height: context.dimens.space8)],
          ],
        ],
      ),
    );
  }
}

/// The one part of this screen that depends on the session.
///
/// A `BlocSelector` rather than a `BlocBuilder`: the builder is handed the
/// [AuthUser] and nothing else, so it cannot read a field the rebuild condition
/// does not cover. That is not a style preference — this widget used to be a
/// `BlocBuilder<SessionCubit, SessionStatus>` whose builder ignored the state
/// and called `context.read<SessionCubit>().user`, so a profile change that
/// left the status at `authenticated` never reached the screen.
class _UserCard extends StatelessWidget {
  const _UserCard();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SessionCubit, SessionState, AuthUser?>(
      selector: (state) => state.user,
      builder: (context, user) => Card(
        child: Padding(
          padding: EdgeInsets.all(context.dimens.space16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: context.colors.brandSubtle,
                child: Text(user?.displayName.initials ?? '?', style: context.textStyles.titleSm),
              ),
              SizedBox(width: context.dimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? 'Guest', style: context.textStyles.titleSm),
                    Text(
                      user?.email ?? 'Not signed in',
                      style: context.textStyles.bodySm.copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAppTile extends StatelessWidget {
  const _MiniAppTile({required this.entry});

  final MiniAppEntryPoint entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(entry.icon, color: context.colors.brand),
        title: Text(entry.title, style: context.textStyles.titleSm),
        subtitle: entry.description == null ? null : Text(entry.description!, style: context.textStyles.bodySm),
        trailing: const Icon(Icons.chevron_right_rounded),
        shape: RoundedRectangleBorder(borderRadius: context.dimens.radiusMdAll),
        onTap: () => entry.onOpen(context),
      ),
    );
  }
}
