import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class LogSink {
  Future<void> write(Map<String, dynamic> entry);
  Future<void> clear();
  Future<String> location();
}

class FileLogSink implements LogSink {
  FileLogSink._(this._file, {required this.maxBytes, required this.maxBackups});

  final File _file;
  final int maxBytes;
  final int maxBackups;

  static Future<FileLogSink> create({
    required File file,
    int maxBytes = 512 * 1024,
    int maxBackups = 1,
  }) async {
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return FileLogSink._(file, maxBytes: maxBytes, maxBackups: maxBackups);
  }

  @override
  Future<void> write(Map<String, dynamic> entry) async {
    final encoded = jsonEncode(entry);
    await _rotateIfNeeded(encoded.length);
    await _file.writeAsString('$encoded\n', mode: FileMode.append);
  }

  Future<void> _rotateIfNeeded(int incomingLength) async {
    if (maxBytes <= 0) return;
    
    final exists = await _file.exists();
    if (!exists) return;
    
    final currentSize = await _file.length();
    if (currentSize + incomingLength <= maxBytes) return;

    if (maxBackups <= 0) {
      await _file.writeAsString('');
      return;
    }

    // Rotate backup files in reverse order
    for (var index = maxBackups - 1; index >= 1; index--) {
      final older = File('${_file.path}.$index');
      final newer = File('${_file.path}.${index + 1}');
      if (await older.exists()) {
        if (await newer.exists()) {
          await newer.delete();
        }
        await older.rename(newer.path);
      }
    }

    // Move current file to .1
    final rollover = File('${_file.path}.1');
    if (await rollover.exists()) {
      await rollover.delete();
    }
    await _file.rename(rollover.path);
    
    // Create new empty file
    await _file.writeAsString('');
  }

  @override
  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.writeAsString('');
    }
    for (var index = 1; index <= maxBackups; index++) {
      final backup = File('${_file.path}.$index');
      if (await backup.exists()) {
        await backup.delete();
      }
    }
  }

  @override
  Future<String> location() async => _file.path;

  Future<String> readAll() async {
    if (await _file.exists()) {
      return _file.readAsString();
    }
    return '';
  }
}

class LoggerService {
  static LogSink? _sink;
  static bool _initialized = false;
  static String _fileName = 'api_log.txt';

  /// Sets up the log sink. Optionally provide a custom [LogSink]; otherwise a
  /// rotating file sink will be created.
  static Future<void> init({
    String? fileName,
    Directory? directory,
    LogSink? sink,
    int maxFileBytes = 512 * 1024,
    int maxBackupFiles = 1,
  }) async {
    if (fileName != null) _fileName = fileName;

    if (sink != null) {
      _sink = sink;
      _initialized = true;
      return;
    }

    final targetDirectory =
        directory ?? await getApplicationDocumentsDirectory();
    final file = File('${targetDirectory.path}/$_fileName');
    _sink = await FileLogSink.create(
      file: file,
      maxBytes: maxFileBytes,
      maxBackups: maxBackupFiles,
    );
    _initialized = true;
  }

  /// Ensures the logger is configured before writing.
  static Future<void> ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  static Future<void> logger(String message) async {
    await ensureInitialized();
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'category': 'legacy',
      'action': message,
    };

    await _write(entry);
  }

  static Future<void> logEvent({
    required String category,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    await ensureInitialized();
    final entry = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'category': category,
      'action': action,
      if (details != null && details.isNotEmpty) 'details': details,
    };

    await _write(entry);
  }

  static Future<void> logUi(
    String action, {
    Map<String, dynamic>? details,
  }) async {
    await logEvent(category: 'ui', action: action, details: details);
  }

  static Future<void> logApi(
    String action, {
    Map<String, dynamic>? request,
    Map<String, dynamic>? response,
    int? statusCode,
    bool? success,
  }) async {
    final details = <String, dynamic>{
      if (request != null && request.isNotEmpty) 'request': request,
      if (response != null && response.isNotEmpty) 'response': response,
      if (statusCode != null) 'statusCode': statusCode,
      if (success != null) 'success': success,
    };

    await logEvent(
      category: 'api',
      action: action,
      details: details.isEmpty ? null : details,
    );
  }

  static Future<void> _write(Map<String, dynamic> entry) async {
    if (_sink == null) return;
    await _sink!.write(entry);
  }

  static Future<void> clearLogs() async {
    await ensureInitialized();
    await _sink?.clear();
  }

  static Future<String> getLogPath() async {
    await ensureInitialized();
    if (_sink == null) return 'Log sink not initialized';
    return _sink!.location();
  }

  static Future<String> readLogs() async {
    await ensureInitialized();
    if (_sink is! FileLogSink) {
      return 'Current log sink does not support readLogs.';
    }
    return (_sink as FileLogSink).readAll();
  }

  /// Resets underlying state. Useful for tests.
  static void resetForTest() {
    _sink = null;
    _initialized = false;
  }
}
