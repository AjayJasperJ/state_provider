import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../domain/entities/pagination_state.dart';
import '../../domain/value_objects/pagination_page.dart';
import '../../utils/dev_logger.dart';

typedef PaginationErrorTransformer<E> =
    E Function(
      E error,
      int page,
      int cachedItemCount,
      bool isInitialFetch,
      bool isRefresh,
    );

/// A reusable [ChangeNotifier] that coordinates paginated data fetching and
/// exposes a [PaginationState] for UI consumption.
class PaginationNotifier<D, E> extends ChangeNotifier {
  PaginationNotifier({
    PaginationFetch<D, E>? fetchPage,
    int initialPage = 0,
    Object? Function(D value)? keySelector,
    bool enableDeduplication = true,
    this.autoLogEvents = true,
    this.onFetchError,
    this.errorTransformer,
  }) : _fetchPage = fetchPage,
       _initialPage = initialPage,
       _keySelector = keySelector,
       _enableDeduplication = enableDeduplication && keySelector != null,
       _currentPage = initialPage - 1;

  final PaginationFetch<D, E>? _fetchPage;
  final int _initialPage;
  final Object? Function(D value)? _keySelector;
  final bool _enableDeduplication;

  /// Controls whether debug logging is emitted via [DevLogger.pagination].
  final bool autoLogEvents;

  /// Optional transformer used when the [fetchPage] callback throws.
  final E Function(Object error, StackTrace stackTrace)? onFetchError;

  /// Optional transformer applied to failures before updating state.
  final PaginationErrorTransformer<E>? errorTransformer;

  PaginationState<D, E> _state = PaginationState<D, E>();
  PaginationState<D, E> get state => _state;

  bool _isFetching = false;
  int _currentPage;
  bool _hasMore = true;
  bool _disposed = false;

  final Set<Object?> _seenKeys = <Object?>{};

  /// Convenience getter exposing the currently cached items.
  List<D> get items => List.unmodifiable(_state.items);

  /// Whether a fetch is currently underway.
  bool get isFetching => _isFetching;

  /// Whether more items are available according to the latest fetch.
  bool get hasMore => _hasMore;

  /// Initiates the first page request. When [force] is true the existing cache
  /// is cleared and the page index resets to [_initialPage].
  Future<void> loadInitial({bool force = true}) async {
    if (_isFetching) return;

    if (force) {
      _currentPage = _initialPage - 1;
      _hasMore = true;
      _seenKeys.clear();
    }

    final initialItems = force ? <D>[] : List<D>.from(_state.items);
    _emit(
      _state.copyWith(
        items: initialItems,
        isInitialLoading: true,
        isLoadingMore: false,
        hasMore: _hasMore,
        clearInitialError: true,
        clearLoadMoreError: true,
      ),
    );

    final cachedItemsBefore = force ? 0 : _state.items.length;
    final isRefresh = force && cachedItemsBefore > 0;

    await _runFetch(
      page: _initialPage,
      cachedItemsBefore: cachedItemsBefore,
      isInitialFetch: true,
      isRefresh: isRefresh,
      onSuccess: (page) {
        _currentPage = page.pageNumber ?? _initialPage;
        _hasMore = page.hasMore;
        _emit(
          _state.copyWith(
            items: _mergeItems(page.items, replace: true),
            isInitialLoading: false,
            isLoadingMore: false,
            hasMore: _hasMore,
            clearInitialError: true,
            clearLoadMoreError: true,
          ),
        );
      },
      onFailure: (error) {
        _emit(_state.copyWith(isInitialLoading: false, initialError: error));
      },
      logLabel: isRefresh ? 'refresh' : 'initial page',
    );
  }

  /// Loads the next page when [hasMore] is true.
  Future<void> loadMore() async {
    if (_isFetching) return;
    if (!_hasMore) return;
    if (_state.isInitialLoading) return;

    final nextPage = _currentPage + 1;

    _emit(_state.copyWith(isLoadingMore: true, clearLoadMoreError: true));

    final cachedItemsBefore = _state.items.length;

    await _runFetch(
      page: nextPage,
      cachedItemsBefore: cachedItemsBefore,
      isInitialFetch: false,
      isRefresh: false,
      onSuccess: (page) {
        _currentPage = page.pageNumber ?? nextPage;
        _hasMore = page.hasMore;
        _emit(
          _state.copyWith(
            items: _mergeItems(page.items),
            isLoadingMore: false,
            hasMore: _hasMore,
            clearLoadMoreError: true,
          ),
        );
      },
      onFailure: (error) {
        _emit(_state.copyWith(isLoadingMore: false, loadMoreError: error));
      },
      logLabel: 'page $nextPage',
    );
  }

  /// Refreshes the entire data set, retrying the first page.
  Future<void> refresh() => loadInitial(force: true);

  /// Replaces the current list of items without triggering network calls.
  void replaceItems(List<D> items, {bool hasMore = true}) {
    _seenKeys.clear();
    if (_enableDeduplication) {
      final selector = _keySelector;
      if (selector != null) {
        for (final item in items) {
          _seenKeys.add(selector(item));
        }
      }
    }
    _hasMore = hasMore;
    _emit(
      _state.copyWith(
        items: List<D>.from(items),
        hasMore: hasMore,
        clearLoadMoreError: true,
        clearInitialError: true,
      ),
    );
  }

  /// Clears any recorded pagination errors while preserving fetched items.
  void clearErrors() {
    _emit(_state.copyWith(clearInitialError: true, clearLoadMoreError: true));
  }

  Future<void> _runFetch({
    required int page,
    required int cachedItemsBefore,
    required bool isInitialFetch,
    required bool isRefresh,
    required void Function(PaginationPage<D> page) onSuccess,
    required void Function(E error) onFailure,
    required String logLabel,
  }) async {
    _isFetching = true;
    _log('Requesting $logLabel', data: {'page': page});

    try {
      final result = await _safeFetch(page);
      if (result.isSuccess) {
        final fetchedPage = result.page!;
        _log(
          'Fetched ${fetchedPage.items.length} items for $logLabel',
          data: {
            'page': page,
            'hasMore': fetchedPage.hasMore,
            if (fetchedPage.totalItems != null)
              'totalItems': fetchedPage.totalItems,
          },
        );
        onSuccess(fetchedPage);
      } else {
        var error =
            result.error ??
            (throw StateError(
              'Pagination fetch failure missing error payload',
            ));
        if (errorTransformer != null) {
          error = errorTransformer!(
            error,
            page,
            cachedItemsBefore,
            isInitialFetch,
            isRefresh,
          );
        }
        _log(
          'Failed to load $logLabel',
          data: {'page': page},
          isError: true,
          error: error,
        );
        onFailure(error);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<PaginationFetchResult<D, E>> _safeFetch(int page) async {
    try {
      return await _invokeFetch(page);
    } catch (error, stackTrace) {
      _log(
        'Fetch callback threw an exception',
        data: {'page': page, 'error': error},
        isError: true,
        stackTrace: stackTrace,
      );
      if (onFetchError != null) {
        return PaginationFetchResult<D, E>.failure(
          onFetchError!(error, stackTrace),
        );
      }
      rethrow;
    }
  }

  @protected
  Future<PaginationFetchResult<D, E>> onFetchPage(int page) async {
    throw UnimplementedError(
      'Either provide a fetchPage callback or override onFetchPage.',
    );
  }

  Future<PaginationFetchResult<D, E>> _invokeFetch(int page) {
    final fetch = _fetchPage ?? onFetchPage;
    return fetch(page);
  }

  List<D> _mergeItems(List<D> incoming, {bool replace = false}) {
    if (replace) {
      _seenKeys.clear();
    }

    final selector = _keySelector;
    if (!_enableDeduplication || selector == null) {
      final base = replace ? <D>[] : List<D>.from(_state.items);
      base.addAll(incoming);
      return base;
    }

    final buffer = replace ? <D>[] : List<D>.from(_state.items);
    for (final item in incoming) {
      final key = selector(item);
      if (_seenKeys.add(key)) {
        buffer.add(item);
      }
    }
    return buffer;
  }

  void _emit(PaginationState<D, E> newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  void _log(
    String message, {
    Object? data,
    bool isError = false,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!autoLogEvents) return;
    if (isError) {
      DevLogger.error(
        message,
        tag: 'PAGINATION_NOTIFIER',
        error: error ?? data,
        stackTrace: stackTrace,
      );
    } else {
      DevLogger.pagination(message, data: data);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
