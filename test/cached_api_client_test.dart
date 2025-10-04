import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:state_provider/state_provider.dart';

void main() {
  group('CachedApiClient', () {
    late Directory tempDir;
    late RequestCacheStore store;
    late RequestCacheManager manager;
    late List<String> requestedUrls;
    late bool isConnected;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cached_api_client_test');
      store = RequestCacheStore(directory: tempDir);
      manager = RequestCacheManager.instance;
      await manager.resetForTest(store: store);
      requestedUrls = [];
      isConnected = false;
    });

    tearDown(() async {
      await manager.resetForTest(store: store);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('queues when offline and replays once online', () async {
      final client = CachedApiClient(
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          return http.Response('{"ok": true}', 200);
        }),
        enableCaching: true,
        autoRegisterInternetService: false,
        isConnectedOverride: () => isConnected,
      );

      final result = await client.getJson('https://example.com/data');

      expect(result.isFailure, isTrue);
      expect(result.asFailure.error.type, AppErrorType.network);
      expect(manager.pending.length, 1);
      expect(requestedUrls, isEmpty);

      isConnected = true;
      await manager.triggerReplay();

      expect(requestedUrls.length, 1);
      expect(manager.pending, isEmpty);
      client.dispose();
    });

    test('successful request clears cache immediately', () async {
      isConnected = true;
      final client = CachedApiClient(
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          return http.Response('{"ok": true}', 200);
        }),
        enableCaching: true,
        autoRegisterInternetService: false,
        isConnectedOverride: () => isConnected,
      );

      final result = await client.postJson(
        'https://example.com/create',
        jsonBody: const {'name': 'foo'},
      );

      expect(result.isSuccess, isTrue);
      expect(manager.pending, isEmpty);
      expect(requestedUrls.length, 1);
      client.dispose();
    });

    test('non-retriable failures are removed from cache', () async {
      isConnected = true;
      final client = CachedApiClient(
        httpClient: MockClient((request) async {
          return http.Response('{"message": "Invalid"}', 400);
        }),
        enableCaching: true,
        autoRegisterInternetService: false,
        isConnectedOverride: () => isConnected,
      );

      final result = await client.postJson(
        'https://example.com/create',
        jsonBody: const {'name': 'bad'},
      );

      expect(result.isFailure, isTrue);
      expect(result.asFailure.error.type, AppErrorType.validation);
      expect(manager.pending, isEmpty);
      client.dispose();
    });
  });
}
