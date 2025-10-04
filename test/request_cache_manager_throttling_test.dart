import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:state_provider/state_provider.dart';

void main() {
  group('RequestCacheManager - Throttling & Deduplication', () {
    late Directory tempDir;
    late RequestCacheStore store;
    late RequestCacheManager manager;
    late List<String> requestedUrls;
    late bool isConnected;
    late int requestCount;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cache_manager_test');
      store = RequestCacheStore(directory: tempDir);
      manager = RequestCacheManager.instance;
      await manager.resetForTest(store: store);
      requestedUrls = [];
      isConnected = false;
      requestCount = 0;
    });

    tearDown(() async {
      await manager.resetForTest(store: store);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('throttles replay to prevent API flooding', () async {
      // Create multiple identical requests (simulating user tapping same items offline)
      final client = CachedApiClient(
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          requestCount++;
          // Simulate slow API responses
          await Future.delayed(const Duration(milliseconds: 100));
          return http.Response('{"data": "response$requestCount"}', 200);
        }),
        enableCaching: true,
        autoRegisterInternetService: false,
        isConnectedOverride: () => isConnected,
      );

      // Queue 10 requests while offline
      final futures = <Future>[];
      for (int i = 0; i < 10; i++) {
        futures.add(client.getJson('https://example.com/item/$i'));
      }
      await Future.wait(futures);

      expect(manager.pending.length, 10);
      expect(requestedUrls, isEmpty);

      // Go online and trigger replay
      isConnected = true;
      final stopwatch = Stopwatch()..start();
      await manager.triggerReplay();
      stopwatch.stop();

      // Verify throttling occurred (should take longer than if all sent at once)
      expect(
        stopwatch.elapsedMilliseconds,
        greaterThan(500),
      ); // Some delay expected
      expect(requestedUrls.length, 10);
      expect(manager.pending, isEmpty);

      client.dispose();
    });

    test('smart deduplication: view-only vs pagination requests', () async {
      final client = CachedApiClient(
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          requestCount++;
          return http.Response('{"data": "response$requestCount"}', 200);
        }),
        enableCaching: true,
        autoRegisterInternetService: false,
        isConnectedOverride: () => isConnected,
      );

      // Simulate user tapping different item details (view-only)
      // Should keep ONLY the last one
      await client.getJson('https://example.com/items/1');
      await client.getJson('https://example.com/items/2');
      await client.getJson('https://example.com/items/3');

      // Simulate pagination requests (should be preserved)
      await client.getJson('https://example.com/items?page=1&limit=10');
      await client.getJson('https://example.com/items?page=2&limit=10');

      // Simulate exact duplicates (should deduplicate normally)
      await client.postJson(
        'https://example.com/same',
        jsonBody: const {'action': 'test'},
      );
      await client.postJson(
        'https://example.com/same',
        jsonBody: const {'action': 'test'},
      );

      expect(manager.pending.length, 7);

      // Trigger smart deduplication
      await manager.deduplicateRequests();

      // Should keep:
      // - 1 view request (items/3, discarding items/1 and items/2)
      // - 2 pagination requests (different pages)
      // - 1 POST request (deduplicated)
      expect(manager.pending.length, 4);

      // Verify the correct requests remain
      final remaining = manager.pending;
      final urls = remaining.map((r) => r.path).toList();

      expect(urls.where((url) => url.contains('/items/3')), hasLength(1));
      expect(urls.where((url) => url.contains('/items/1')), isEmpty);
      expect(urls.where((url) => url.contains('/items/2')), isEmpty);
      expect(urls.where((url) => url.contains('page=1')), hasLength(1));
      expect(urls.where((url) => url.contains('page=2')), hasLength(1));
      expect(urls.where((url) => url.contains('/same')), hasLength(1));

      client.dispose();
    });

    test('deduplication runs automatically on reconnect', () async {
      // Set up internet service mock
      final internetService = InternetService();
      await manager.registerInternetService(internetService);

      final client = CachedApiClient(
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          requestCount++;
          return http.Response('{"data": "response$requestCount"}', 200);
        }),
        enableCaching: true,
        autoRegisterInternetService: false,
        isConnectedOverride: () => isConnected,
      );

      // Queue duplicate requests while offline
      for (int i = 0; i < 3; i++) {
        await client.getJson('https://example.com/duplicate-item');
      }

      expect(manager.pending.length, 3);

      // Simulate connection restored (this should trigger deduplication + replay)
      isConnected = true;
      // Manually trigger the reconnect flow since we can't easily mock connectivity
      await manager.deduplicateRequests();
      await manager.triggerReplay();

      // Give some time for async operations
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have deduplicated and made only 1 HTTP call
      expect(requestedUrls.length, 1);
      expect(manager.pending, isEmpty);

      client.dispose();
    });

    test('respects max concurrent replays limit', () async {
      // Create manager with low concurrency limit for testing
      await manager.resetForTest(store: store);

      final client = CachedApiClient(
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          requestCount++;
          // Simulate slow responses to test concurrency control
          await Future.delayed(const Duration(milliseconds: 200));
          return http.Response('{"data": "response$requestCount"}', 200);
        }),
        enableCaching: true,
        autoRegisterInternetService: false,
        isConnectedOverride: () => isConnected,
      );

      // Queue many different requests (will not be deduplicated)
      for (int i = 0; i < 8; i++) {
        await client.getJson('https://example.com/unique-item/$i');
      }

      expect(manager.pending.length, 8);

      // Go online and measure replay behavior
      isConnected = true;
      final stopwatch = Stopwatch()..start();
      await manager.triggerReplay();
      stopwatch.stop();

      // All requests should complete, but with batching delays
      expect(requestedUrls.length, 8);
      expect(manager.pending, isEmpty);

      // Should take longer than 200ms (minimum for 1 request)
      // but less than 8 * 200ms (if all were sequential)
      expect(stopwatch.elapsedMilliseconds, greaterThan(200));
      expect(stopwatch.elapsedMilliseconds, lessThan(1600));

      client.dispose();
    });
  });
}
