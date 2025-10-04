import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LoggerService {
  static File? _logFile;
  static bool _initialized = false;
  static String _fileName = 'api_log.txt';

  /// Sets up the log file. Safe to call multiple times.
  static Future<void> init({String? fileName, Directory? directory}) async {
    if (fileName != null) _fileName = fileName;

    final targetDirectory =
        directory ?? await getApplicationDocumentsDirectory();
    _logFile = File('${targetDirectory.path}/$_fileName');

    if (!await _logFile!.exists()) {
      await _logFile!.create(recursive: true);
    }
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

    await _writeLine(jsonEncode(entry));
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

    await _writeLine(jsonEncode(entry));
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

  static Future<void> _writeLine(String line) async {
    if (_logFile != null) {
      await _logFile!.writeAsString('$line\n', mode: FileMode.append);
    }
  }

  static Future<void> clearLogs() async {
    await ensureInitialized();
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }

  static Future<String> getLogPath() async {
    await ensureInitialized();
    return _logFile?.path ?? 'Log file not initialized';
  }

  static Future<String> readLogs() async {
    await ensureInitialized();
    if (_logFile != null && await _logFile!.exists()) {
      return await _logFile!.readAsString();
    }
    return '';
  }

  /// Resets underlying state. Useful for tests.
  static void resetForTest() {
    _logFile = null;
    _initialized = false;
  }
}
