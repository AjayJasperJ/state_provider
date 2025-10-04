import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:state_provider/state_provider.dart';

void main() {
  group('LoggerService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('logger_service_test');
      LoggerService.resetForTest();
      await LoggerService.init(directory: tempDir, fileName: 'test.log');
      await LoggerService.clearLogs();
    });

    tearDown(() async {
      LoggerService.resetForTest();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('logUi appends structured json entry', () async {
      await LoggerService.logUi('opened_home', details: {'screen': 'home'});

      final contents = await LoggerService.readLogs();
      expect(contents, contains('"category":"ui"'));
      expect(contents, contains('"action":"opened_home"'));
      expect(contents, contains('"screen":"home"'));
    });

    test('logApi writes success metadata', () async {
      await LoggerService.logApi(
        'GET /items',
        statusCode: 200,
        success: true,
        request: const {'path': '/items'},
        response: const {
          'data': [1, 2, 3],
        },
      );

      final contents = await LoggerService.readLogs();
      expect(contents, contains('"category":"api"'));
      expect(contents, contains('"statusCode":200'));
      expect(contents, contains('"success":true'));
    });
  });
}
