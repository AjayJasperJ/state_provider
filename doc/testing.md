# Testing Guide

The `state_provider` package ships with unit, widget, and integration-style tests to guard critical behavior. This guide explains the existing coverage and how to extend it.

## Current test suites

| File | Focus |
| --- | --- |
| `test/pagination_notifier_test.dart` | Validates pagination life cycle: initial load, load-more, deduplication, and error propagation. |
| `test/api_client_test.dart` | Verifies successful JSON parsing, error mapping, auth header injection, and serialization failure handling. |
| `test/logger_service_test.dart` | Covers structured logging, custom sink injection, and file rotation behavior. |
| `test/state_handler_widget_test.dart` | Exercises UI builders, empty-state detection, and retry flows for `StateHandler`. |

## Running the suite

```bash
cd packages/state_provider
flutter test --coverage
```

The CI workflow (`.github/workflows/ci.yaml`) runs `flutter analyze` and `flutter test --coverage` on every push and pull request, uploading `coverage/lcov.info` as an artifact.

## Adding new tests

1. **Widgets:** When introducing new presentation widgets, create `test/<widget>_test.dart` using `WidgetTester` to verify builders and interactions.
2. **Data sources:** Mock dependencies (`http.Client`, storage) to validate error branches and retry behavior.
3. **Integration:** Compose end-to-end provider + widget scenarios to model your app’s usage patterns.

## Tips

- Use `LoggerService.resetForTest()` to isolate log state between tests.
- Provide custom `LogSink` implementations for deterministic assertions.
- For pagination flows, leverage fake repositories that return deterministic `PaginationFetchResult` values.
