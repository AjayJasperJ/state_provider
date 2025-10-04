import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:state_provider/state_provider.dart';

class _MemorySink implements LogSink {
  final List<Map<String, dynamic>> entries = [];

  @override
  Future<void> clear() async => entries.clear();

  @override
  Future<String> location() async => 'memory://sink';

  @override
  Future<void> write(Map<String, dynamic> entry) async {
    entries.add(entry);
  }
}

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

    test('supports custom sink injection', () async {
      final sink = _MemorySink();
      LoggerService.resetForTest();
      await LoggerService.init(sink: sink);

      await LoggerService.logEvent(category: 'custom', action: 'event');

      expect(sink.entries, hasLength(1));
      expect(sink.entries.single['category'], 'custom');
    });

    test('rotates file when max size exceeded', () async {
      LoggerService.resetForTest();
      const fileName = 'rotate.log';
      await LoggerService.init(
        directory: tempDir,
        fileName: fileName,
        maxFileBytes: 120,
        maxBackupFiles: 1,
      );

      for (var i = 0; i < 6; i++) {
        await LoggerService.logEvent(
          category: 'rotation',
          action: 'entry_$i',
          details: {'payload': 'x' * 80},
        );
      }

      final active = await LoggerService.readLogs();
      final backup = File('${tempDir.path}/$fileName.1');

      expect(
        active.split('\n').where((line) => line.isNotEmpty).length,
        lessThan(6),
      );
      expect(await backup.exists(), isTrue);
    });
  });
}
