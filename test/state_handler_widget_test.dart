import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:state_provider/state_provider.dart';

class _TestNotifier extends ChangeNotifier {
  LoadState<String> _state = const LoadState();

  LoadState<String> get state => _state;

  void update(LoadState<String> newState) {
    _state = newState;
    notifyListeners();
  }
}

class _IterableNotifier extends ChangeNotifier {
  LoadState<List<String>> _state = const LoadState();

  LoadState<List<String>> get state => _state;

  void update(LoadState<List<String>> newState) {
    _state = newState;
    notifyListeners();
  }
}

Widget _wrapNotifier<T extends ChangeNotifier>({
  required T notifier,
  required Widget child,
}) {
  return ChangeNotifierProvider<T>.value(
    value: notifier,
    child: MaterialApp(home: child),
  );
}

void main() {
  group('StateHandler', () {
    testWidgets('renders builders for loading and success states', (
      tester,
    ) async {
      final notifier = _TestNotifier();
      notifier.update(LoadState.loading());

      await tester.pumpWidget(
        _wrapNotifier(
          notifier: notifier,
          child: StateHandler<_TestNotifier, String>(
            state: (_, provider) => provider.state,
            loadingBuilder: (_, __) => const Text('loading'),
            successBuilder: (_, __, data) => Text('data: $data'),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);

      notifier.update(LoadState.success('fetched'));
      await tester.pumpAndSettle();

      expect(find.text('data: fetched'), findsOneWidget);
    });

    testWidgets('renders empty builder when iterable data is empty', (
      tester,
    ) async {
      final notifier = _IterableNotifier();
      notifier.update(LoadState.success<List<String>>(<String>[]));

      await tester.pumpWidget(
        _wrapNotifier(
          notifier: notifier,
          child: StateHandler<_IterableNotifier, List<String>>(
            state: (_, provider) => provider.state,
            emptyBuilder: (_, __) => const Text('empty'),
            successBuilder: (_, __, data) => Text('data: ${data.length}'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('empty'), findsOneWidget);
      expect(find.textContaining('data:'), findsNothing);
    });

    testWidgets('shows retry button and calls onInit on retry', (tester) async {
      final notifier = _TestNotifier();
      final errors = <String>[];
      var onInitCalls = 0;

      notifier.update(
        LoadState.failure<String>(AppError.server(message: 'boom')),
      );

      await tester.pumpWidget(
        _wrapNotifier(
          notifier: notifier,
          child: StateHandler<_TestNotifier, String>(
            state: (_, provider) => provider.state,
            onInit: (provider) async {
              onInitCalls++;
              if (onInitCalls >= 2) {
                provider.update(LoadState.success('recovered'));
              }
            },
            failureBuilder: (_, __, error, ___, retry) {
              errors.add(error.message);
              return Column(
                children: [
                  Text(error.message),
                  ElevatedButton(
                    onPressed: retry,
                    child: const Text('Retry now'),
                  ),
                ],
              );
            },
            successBuilder: (_, __, data) => Text('ok: $data'),
          ),
        ),
      );

      expect(errors.single, contains('boom'));
      expect(find.text('Retry now'), findsOneWidget);

      await tester.pump();
      expect(onInitCalls, equals(1));
      expect(find.text('Retry now'), findsOneWidget);

      await tester.tap(find.text('Retry now'));
      await tester.pumpAndSettle();

      expect(onInitCalls, equals(2));
      expect(find.text('ok: recovered'), findsOneWidget);
    });
  });
}
