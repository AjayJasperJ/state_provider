import 'package:flutter/material.dart';

/// Paginated list view that appends loading and error indicators as new items.
class PaginationListView<D, E> extends StatelessWidget {
  const PaginationListView({
    super.key,
    required this.controller,
    required this.items,
    required this.itemBuilder,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.onRetryLoadMore,
    this.loadingMoreBuilder,
    this.loadMoreErrorBuilder,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.primary,
  });

  final ScrollController controller;
  final List<D> items;
  final Widget Function(BuildContext, int, D) itemBuilder;
  final bool isLoadingMore;
  final E? loadMoreError;
  final Future<void> Function()? onRetryLoadMore;
  final WidgetBuilder? loadingMoreBuilder;
  final Widget Function(BuildContext, E, Future<void> Function()?)?
  loadMoreErrorBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool? primary;

  @override
  Widget build(BuildContext context) {
    final trailing = _buildTrailingWidgets<E>(
      context: context,
      isLoadingMore: isLoadingMore,
      loadMoreError: loadMoreError,
      onRetryLoadMore: onRetryLoadMore,
      loadingMoreBuilder: loadingMoreBuilder,
      loadMoreErrorBuilder: loadMoreErrorBuilder,
    );

    return ListView.builder(
      controller: controller,
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      primary: primary,
      itemCount: items.length + trailing.length,
      itemBuilder: (context, index) {
        if (index < items.length) {
          return itemBuilder(context, index, items[index]);
        }
        return trailing[index - items.length];
      },
    );
  }
}

/// Grid variant of the paginated collection view.
class PaginationGridView<D, E> extends StatelessWidget {
  const PaginationGridView({
    super.key,
    required this.controller,
    required this.items,
    required this.itemBuilder,
    required this.gridDelegate,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.onRetryLoadMore,
    this.loadingMoreBuilder,
    this.loadMoreErrorBuilder,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.primary,
  });

  final ScrollController controller;
  final List<D> items;
  final Widget Function(BuildContext, int, D) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final bool isLoadingMore;
  final E? loadMoreError;
  final Future<void> Function()? onRetryLoadMore;
  final WidgetBuilder? loadingMoreBuilder;
  final Widget Function(BuildContext, E, Future<void> Function()?)?
  loadMoreErrorBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool? primary;

  @override
  Widget build(BuildContext context) {
    final trailing = _buildTrailingWidgets<E>(
      context: context,
      isLoadingMore: isLoadingMore,
      loadMoreError: loadMoreError,
      onRetryLoadMore: onRetryLoadMore,
      loadingMoreBuilder: loadingMoreBuilder,
      loadMoreErrorBuilder: loadMoreErrorBuilder,
    );

    return GridView.builder(
      controller: controller,
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      primary: primary,
      itemCount: items.length + trailing.length,
      gridDelegate: gridDelegate,
      itemBuilder: (context, index) {
        if (index < items.length) {
          return itemBuilder(context, index, items[index]);
        }
        return trailing[index - items.length];
      },
    );
  }
}

List<Widget> _buildTrailingWidgets<E>({
  required BuildContext context,
  required bool isLoadingMore,
  required E? loadMoreError,
  required Future<void> Function()? onRetryLoadMore,
  required WidgetBuilder? loadingMoreBuilder,
  required Widget Function(BuildContext, E, Future<void> Function()?)?
  loadMoreErrorBuilder,
}) {
  final trailing = <Widget>[];

  if (isLoadingMore) {
    trailing.add(
      loadingMoreBuilder?.call(context) ??
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
    );
  }

  if (loadMoreError != null) {
    trailing.add(
      (loadMoreErrorBuilder ?? _defaultLoadMoreErrorBuilder)(
        context,
        loadMoreError,
        onRetryLoadMore,
      ),
    );
  }

  return trailing;
}

Widget _defaultLoadMoreErrorBuilder<E>(
  BuildContext context,
  E error,
  Future<void> Function()? retry,
) {
  final message = error?.toString() ?? 'Something went wrong.';
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16.0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Error while loading more: $message'),
        if (retry != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      ],
    ),
  );
}
