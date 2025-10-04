import 'package:flutter/foundation.dart';

@immutable
class PaginationState<D, E> {
  const PaginationState({
    this.items = const [],
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.initialError,
    this.loadMoreError,
  });

  final List<D> items;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final E? initialError;
  final E? loadMoreError;

  PaginationState<D, E> copyWith({
    List<D>? items,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    E? initialError,
    E? loadMoreError,
    bool clearInitialError = false,
    bool clearLoadMoreError = false,
  }) {
    return PaginationState<D, E>(
      items: items ?? this.items,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      initialError: clearInitialError
          ? null
          : initialError ?? this.initialError,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }

  bool get hasItems => items.isNotEmpty;
  bool get isEmpty => items.isEmpty;
  bool get hasInitialError => initialError != null;
  bool get hasLoadMoreError => loadMoreError != null;
  bool get isLoading => isInitialLoading || isLoadingMore;
}
