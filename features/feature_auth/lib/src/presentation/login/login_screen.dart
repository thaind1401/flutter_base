import 'package:core_arch/core_arch.dart';
// `Email` and `Password` are now named in this file: a selector's type argument
// is what makes the slice explicit, which is the whole point of BlocSelector.
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/src/presentation/login/login_bloc.dart';
import 'package:feature_auth/src/presentation/login/login_state.dart';
import 'package:flutter/material.dart';

/// Reference screen.
///
/// The shape to copy: the route supplies the bloc, the screen only renders
/// state and dispatches events. No business rules, no `Result`, no repository —
/// and no navigation decision beyond reacting to an effect.
///
/// Note the granularity. The screen is a tree of small `const` widgets, each
/// subscribing to one slice of the state through [BlocSelector]. Typing in the
/// password field rebuilds the password field, not the email field, not the
/// button, not the scaffold. See ADR-0008 for why this is the default rather
/// than an optimisation applied later.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.onAuthenticated});

  /// Where to go after a successful sign-in. Injected by the host so this
  /// package does not need to know the app's home route exists.
  final VoidCallback? onAuthenticated;

  @override
  Widget build(BuildContext context) {
    return BlocEffectListener<LoginBloc, LoginEffect>(
      onEffect: (context, effect) => switch (effect) {
        LoginSucceeded() => onAuthenticated?.call(),
        LoginFailed(:final failure) => context.showFailureToast(failure),
      },
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padded: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: context.dimens.space48),
            Text('Welcome back', style: context.textStyles.titleLg),
            SizedBox(height: context.dimens.space4),
            Text('Sign in to continue', style: context.textStyles.bodyMd.copyWith(color: context.colors.textSecondary)),
            SizedBox(height: context.dimens.space32),
            const _EmailField(),
            SizedBox(height: context.dimens.space16),
            const _PasswordField(),
            SizedBox(height: context.dimens.space24),
            const _SubmitButton(),
          ],
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField();

  @override
  Widget build(BuildContext context) {
    // The selector is both the rebuild condition and the only thing the builder
    // can see, so the two cannot drift apart. With `BlocBuilder` + `buildWhen`
    // they are separate expressions: add a field to the builder, forget it in
    // buildWhen, and this field silently stops updating — no crash, no
    // analyzer warning, no failing test.
    return BlocSelector<LoginBloc, LoginState, Email>(
      selector: (state) => state.email,
      builder: (context, email) => AppTextField(
        label: 'Email',
        hint: 'you@example.com',
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        // `displayError` is null while the field is pristine, so an untouched
        // form does not open covered in red.
        errorText: context.messageFor(email.displayError),
        onChanged: (value) => context.read<LoginBloc>().add(LoginEmailChanged(value)),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LoginBloc, LoginState, Password>(
      selector: (state) => state.password,
      builder: (context, password) => AppTextField(
        label: 'Password',
        obscureText: true,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        errorText: context.messageFor(password.displayError),
        onChanged: (value) => context.read<LoginBloc>().add(LoginPasswordChanged(value)),
        onSubmitted: (_) => context.read<LoginBloc>().add(const LoginSubmitted()),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton();

  @override
  Widget build(BuildContext context) {
    // Two fields, still one selector: a record has value equality, so this
    // rebuilds when either changes and never when neither does. Reach for a
    // record rather than falling back to `BlocBuilder` — the moment the builder
    // takes the whole state, nothing stops it reading a fourth field that the
    // rebuild condition does not cover.
    return BlocSelector<LoginBloc, LoginState, ({bool canSubmit, bool isSubmitting})>(
      selector: (state) => (canSubmit: state.canSubmit, isSubmitting: state.isSubmitting),
      builder: (context, submit) => AppButton(
        label: 'Sign in',
        isLoading: submit.isSubmitting,
        onPressed: submit.canSubmit ? () => context.read<LoginBloc>().add(const LoginSubmitted()) : null,
      ),
    );
  }
}
