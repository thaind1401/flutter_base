import 'package:core_arch/core_arch.dart';
import 'package:core_kit/core_kit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:mini_app_sample/src/domain/article.dart';
import 'package:mini_app_sample/src/presentation/article_list_bloc.dart';
import 'package:mini_app_sample/src/sample_mini_app.dart';

/// Reference list screen: pagination, pull-to-refresh, empty and error states,
/// all from the design system with no per-screen plumbing.
class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Articles',
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bloc = context.read<ArticleListBloc>();
          final created = await SampleMiniApp.compose.push<bool>(context);
          // `true` only on a successful create (see ComposeSucceeded in
          // compose_article_screen.dart) — a back-button cancel returns null
          // and must not trigger a refresh.
          if (created ?? false) bloc.add(const ArticleListRefreshed());
        },
        child: const Icon(Icons.add),
      ),
      // The documented exception to ADR-0008's "select a slice, not the state":
      // this bloc's state *is* the one thing on screen, and `PagedListView`
      // reads all of it — items, hasMore, isRefreshing, the failure. Selecting
      // it field by field would rebuild the same widget for the same reasons
      // with more code. `BlocBuilder` with no `buildWhen` is right here because
      // bloc already suppresses an emit of an equal state.
      //
      // The test is whether anything on this screen is independent of the
      // state. Add a header or a filter bar and it stops being true — then this
      // splits into `const` children with their own selectors.
      body: BlocBuilder<ArticleListBloc, PagedViewState<Article>>(
        builder: (context, state) => PagedListView<Article>(
          state: state,
          padding: EdgeInsets.symmetric(horizontal: context.dimens.pagePadding, vertical: context.dimens.space8),
          onLoadMore: () => context.read<ArticleListBloc>().add(const ArticleListLoadMore()),
          onRetry: () => context.read<ArticleListBloc>().add(const ArticleListLoadMore()),
          onRefresh: () async {
            final bloc = context.read<ArticleListBloc>()..add(const ArticleListRefreshed());
            // Keeps the refresh spinner up until the bloc settles, instead of
            // snapping away the moment the gesture ends.
            await bloc.stream.firstWhere((state) => !state.isRefreshing);
          },
          itemBuilder: (context, article, index) => _ArticleTile(article: article),
        ),
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.dimens.space16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.dimens.radiusMdAll,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(article.title, style: context.textStyles.titleSm)),
              // What createArticle's category and featured fields are for:
              // proof, on the read side, that the compose form's dropdown and
              // switch produced a real value rather than being collected and
              // discarded.
              if (article.featured) ...[
                Icon(Icons.star_rounded, size: context.dimens.iconSm, color: context.colors.warning),
                SizedBox(width: context.dimens.space4),
              ],
              _CategoryChip(category: article.category),
            ],
          ),
          SizedBox(height: context.dimens.space4),
          Text(article.summary, style: context.textStyles.bodySm.copyWith(color: context.colors.textSecondary)),
          SizedBox(height: context.dimens.space8),
          Text(
            article.publishedAt.format('dd MMM yyyy'),
            style: context.textStyles.caption.copyWith(color: context.colors.textDisabled),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final ArticleCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.dimens.space8, vertical: context.dimens.space2),
      decoration: BoxDecoration(color: context.colors.brandSubtle, borderRadius: context.dimens.radiusPillAll),
      child: Text(category.name, style: context.textStyles.caption.copyWith(color: context.colors.brand)),
    );
  }
}
