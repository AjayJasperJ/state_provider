# Utilities & Logging

**Files covered:**

- `lib/src/utils/dev_logger.dart`
- `lib/src/data/datasources/logger_service.dart`

## `dev_logger.dart`
Convenience logger designed for quick, colorful console output during development builds.

### Highlights
- Static methods: `success`, `error`, `info`, `api`, `pagination`, `connectivity`.
- Automatically no-ops in non-debug builds to avoid runtime overhead.
- Emits tagged messages to help track signals in the console and test output.

**Use it when:** you want lightweight breadcrumbs while developing or debugging pagination flows, API calls, or connectivity changes.

Example:
```dart
DevLogger.pagination('Fetched next page', data: {'page': 3});
DevLogger.error('Failed to parse response', error: exception);
```

## `logger_service.dart`
The production-grade logging backbone. It writes JSON entries, supports rotation, and accepts custom sinks for advanced routing.

### Typical setup
```dart
await LoggerService.init(
  fileName: 'state_provider.log',
  maxFileBytes: 512 * 1024,
  maxBackupFiles: 2,
);
```

To forward logs elsewhere:
```dart
class MyRemoteSink implements LogSink {
  @override
  Future<void> write(Map<String, dynamic> entry) async {
    await remoteClient.send(entry);
  }

  @override
  Future<void> clear() async {}

  @override
  Future<String> location() async => 'remote://logging-endpoint';
}

await LoggerService.init(sink: MyRemoteSink());
```

### Relationship between DevLogger & LoggerService
- `DevLogger` is for immediate, transient console visibility.
- `LoggerService` is for structured, persisted logs that can be collected or analyzed.

By default, `ApiClient` hooks into `LoggerService` when you supply a `logKey`, enabling end-to-end request auditing with minimal setup.
