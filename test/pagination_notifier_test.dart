import 'package:flutter_test/flutter_test.dart';
import 'package:state_provider/state_provider.dart';

void main() {
  group('PaginationNotifier', () {
    test('loadInitial and loadMore update state with fetched items', () async {
      final notifier = PaginationNotifier<int, String>(
        fetchPage: (page) async {
          final items = List<int>.generate(2, (index) => page * 10 + index);
          final hasMore = page < 1;
          return PaginationFetchResult.success(
            PaginationPage(items: items, hasMore: hasMore, pageNumber: page),
          );
        },
      );

      await notifier.loadInitial();

      expect(notifier.state.items, [0, 1]);
      expect(notifier.state.hasMore, isTrue);
      expect(notifier.isFetching, isFalse);

      await notifier.loadMore();

      expect(notifier.state.items, [0, 1, 10, 11]);
      expect(notifier.state.hasMore, isFalse);
      expect(notifier.state.loadMoreError, isNull);
    });

    test('deduplicates items when keySelector provided', () async {
      final notifier = PaginationNotifier<Map<String, int>, String>(
        keySelector: (item) => item['id'],
        fetchPage: (page) async {
          final items = [
            {'id': 1, 'page': page},
            {'id': 2, 'page': page},
          ];
          return PaginationFetchResult.success(
            PaginationPage(items: items, hasMore: page < 0, pageNumber: page),
          );
        },
      );

      await notifier.loadInitial();
      await notifier.loadMore();

      expect(notifier.state.items.length, 2);
      expect(notifier.state.items.map((item) => item['id']).toList(), [1, 2]);
    });

    test('propagates failures into state errors for initial load', () async {
      const errorMessage = 'network down';
      var shouldFail = true;
      final notifier = PaginationNotifier<int, String>(
        fetchPage: (page) async {
          if (shouldFail) {
            shouldFail = false;
            return const PaginationFetchResult.failure(errorMessage);
          }
          return PaginationFetchResult.success(
            PaginationPage(items: [page], hasMore: false, pageNumber: page),
          );
        },
      );

      await notifier.loadInitial();

      expect(notifier.state.initialError, errorMessage);
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.isInitialLoading, isFalse);

      // Retry succeeds
      await notifier.loadInitial(force: true);
      expect(notifier.state.initialError, isNull);
      expect(notifier.state.items, [0]);
    });

    test('records loadMoreError without duplicating requests', () async {
      var failNext = true;
      final notifier = PaginationNotifier<int, String>(
        fetchPage: (page) async {
          if (failNext) {
            failNext = false;
            return const PaginationFetchResult.failure('rate limited');
          }
          return PaginationFetchResult.success(
            PaginationPage(items: [page], hasMore: false, pageNumber: page),
          );
        },
      );

      await notifier.loadInitial();
      await notifier.loadMore();

      expect(notifier.state.loadMoreError, 'rate limited');
      expect(notifier.state.items, [0, 1]);

      await notifier.loadMore();
      expect(notifier.state.loadMoreError, isNull);
      expect(notifier.state.hasMore, isFalse);
    });
  });
}
