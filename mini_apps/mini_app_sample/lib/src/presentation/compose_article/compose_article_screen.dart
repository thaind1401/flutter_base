import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_sample/src/domain/article.dart';
import 'package:mini_app_sample/src/presentation/compose_article/compose_article_bloc.dart';

/// Second reference screen, alongside `login_screen.dart` in `feature_auth`.
///
/// Login demonstrates the pattern with two text fields. This one demonstrates
/// it with five independent fields of four different kinds — text, dropdown,
/// date, switch — none of them a `BlocBuilder`. Editing the date never
/// rebuilds the title field; toggling "Featured" never rebuilds the category
/// dropdown. Each private widget below owns exactly one `BlocSelector` (or, for
/// the submit button, one record combining the two fields it actually needs —
/// see ADR-0008).
class ComposeArticleScreen extends StatelessWidget {
  const ComposeArticleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocEffectListener<ComposeArticleBloc, ComposeArticleEffect>(
      onEffect: (context, effect) => switch (effect) {
        ComposeSucceeded() => Navigator.of(context).pop(true),
        ComposeFailed(:final failure) => context.showFailureToast(failure),
      },
      child: const _ComposeView(),
    );
  }
}

class _ComposeView extends StatelessWidget {
  const _ComposeView();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'New article',
      padded: true,
      bottomBar: const _SubmitButton(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TitleField(),
            SizedBox(height: context.dimens.space16),
            const _CategoryDropdown(),
            SizedBox(height: context.dimens.space16),
            const _PublishedAtField(),
            SizedBox(height: context.dimens.space16),
            const _SummaryField(),
            SizedBox(height: context.dimens.space8),
            const _FeaturedSwitch(),
          ],
        ),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ComposeArticleBloc, ComposeArticleState, RequiredText>(
      selector: (state) => state.title,
      builder: (context, title) => AppTextField(
        label: 'Title',
        hint: 'What is the article about?',
        textInputAction: TextInputAction.next,
        errorText: context.messageFor(title.displayError),
        onChanged: (value) => context.read<ComposeArticleBloc>().add(ComposeTitleChanged(value)),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown();

  static const _items = [
    AppDropdownItem(value: ArticleCategory.news, label: 'News'),
    AppDropdownItem(value: ArticleCategory.tutorial, label: 'Tutorial'),
    AppDropdownItem(value: ArticleCategory.announcement, label: 'Announcement'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ComposeArticleBloc, ComposeArticleState, ArticleCategory>(
      selector: (state) => state.category,
      builder: (context, category) => AppDropdownField<ArticleCategory>(
        label: 'Category',
        items: _items,
        value: category,
        onChanged: (value) {
          if (value != null) context.read<ComposeArticleBloc>().add(ComposeCategoryChanged(value));
        },
      ),
    );
  }
}

class _PublishedAtField extends StatelessWidget {
  const _PublishedAtField();

  @override
  Widget build(BuildContext context) {
    // Selects the whole state rather than a slice: the error text depends on
    // `isValid`, which reads three fields, so there is no single-field
    // selector that would notice every case that changes it. See ADR-0008 —
    // this is the "whole state is what the widget needs" exception, applied to
    // one field rather than to the whole screen.
    return BlocSelector<ComposeArticleBloc, ComposeArticleState, ({DateTime? publishedAt, bool showError})>(
      selector: (state) => (publishedAt: state.publishedAt, showError: state.status == FormzSubmissionStatus.failure),
      builder: (context, field) => AppDateField(
        label: 'Publish date',
        hint: 'Select a date',
        value: field.publishedAt,
        errorText: field.showError && field.publishedAt == null ? 'A publish date is required' : null,
        onChanged: (value) => context.read<ComposeArticleBloc>().add(ComposePublishedAtChanged(value)),
      ),
    );
  }
}

class _SummaryField extends StatelessWidget {
  const _SummaryField();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ComposeArticleBloc, ComposeArticleState, RequiredText>(
      selector: (state) => state.summary,
      builder: (context, summary) => AppTextField(
        label: 'Summary',
        hint: 'A couple of sentences for the list preview',
        maxLines: 4,
        errorText: context.messageFor(summary.displayError),
        onChanged: (value) => context.read<ComposeArticleBloc>().add(ComposeSummaryChanged(value)),
      ),
    );
  }
}

class _FeaturedSwitch extends StatelessWidget {
  const _FeaturedSwitch();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ComposeArticleBloc, ComposeArticleState, bool>(
      selector: (state) => state.featured,
      builder: (context, featured) => AppSwitchTile(
        title: 'Featured',
        subtitle: 'Pin this article to the top of the list',
        value: featured,
        onChanged: (value) => context.read<ComposeArticleBloc>().add(ComposeFeaturedChanged(value)),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ComposeArticleBloc, ComposeArticleState, ({bool canSubmit, bool isSubmitting})>(
      selector: (state) => (canSubmit: state.canSubmit, isSubmitting: state.isSubmitting),
      builder: (context, submit) => AppButton(
        label: 'Publish',
        isLoading: submit.isSubmitting,
        onPressed: submit.canSubmit ? () => context.read<ComposeArticleBloc>().add(const ComposeSubmitted()) : null,
      ),
    );
  }
}
