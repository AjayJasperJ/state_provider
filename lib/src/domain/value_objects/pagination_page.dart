import 'package:flutter/foundation.dart';

/// Represents a single page of paginated data returned by a data source.
@immutable
class PaginationPage<D> {
  const PaginationPage({
    required this.items,
    required this.hasMore,
    this.pageNumber,
    this.totalItems,
  });

  /// Items returned for this page request.
  final List<D> items;

  /// Whether additional pages are available after this one.
  final bool hasMore;

  /// Optional page number supplied by the backend. Useful when page indices
  /// are not strictly sequential or do not start at zero.
  final int? pageNumber;

  /// Optional total item count reported by the backend/API.
  final int? totalItems;
}

/// Result wrapper for pagination fetch operations.
class PaginationFetchResult<D, E> {
  const PaginationFetchResult._({this.page, this.error});

  /// Successful page fetch.
  const PaginationFetchResult.success(PaginationPage<D> page)
    : this._(page: page);

  /// Failed page fetch.
  const PaginationFetchResult.failure(E error) : this._(error: error);

  final PaginationPage<D>? page;
  final E? error;

  bool get isSuccess => page != null;
  bool get isFailure => error != null;
}

/// Signature for page fetch callbacks consumed by [PaginationNotifier].
typedef PaginationFetch<D, E> =
    Future<PaginationFetchResult<D, E>> Function(int page);
