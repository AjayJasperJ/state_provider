import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_provider/state_provider.dart';

void main() {
  group('PaginationListView', () {
    testWidgets('renders items and loading indicator as trailing widgets', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginationListView<int, String>(
              controller: controller,
              items: const [1, 2],
              isLoadingMore: true,
              itemBuilder: (context, index, item) => Text('Item $item'),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('PaginationGridView', () {
    testWidgets('renders grid layout and load-more error content', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginationGridView<int, String>(
              controller: controller,
              items: const [1, 2, 3, 4],
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              loadMoreError: 'boom',
              onRetryLoadMore: () async {},
              itemBuilder: (context, index, item) =>
                  Center(child: Text('Grid $item')),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Grid 1'), findsOneWidget);
      expect(find.text('Grid 4'), findsOneWidget);
      expect(find.text('Error while loading more: boom'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
