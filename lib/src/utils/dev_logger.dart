import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Developer logger with colored console output.
/// Emits output only in debug mode to avoid leaking logs in release builds.
class DevLogger {
  static const String _name = 'DevLogger';

  // ANSI color codes for terminal output
  static const String _greenColor = '\x1B[32m'; // Green
  static const String _yellowColor = '\x1B[33m'; // Yellow
  static const String _redColor = '\x1B[31m'; // Red
  static const String _blueColor = '\x1B[34m'; // Blue
  static const String _resetColor = '\x1B[0m'; // Reset
  static const String _boldColor = '\x1B[1m'; // Bold

  static void success(String message, {String? tag, Object? data}) =>
      _runInDebug(() {
        final logTag = tag ?? 'SUCCESS';
        final now = DateTime.now();
        final timestamp = now.toIso8601String();
        final formattedMessage =
            '$_greenColor$_boldColor✅ [$logTag] $message$_resetColor';

        developer.log(
          formattedMessage,
          time: now,
          name: _name,
          level: 800, // Info level
        );
        debugPrint('[$timestamp] $formattedMessage');

        if (data != null) {
          final dataMessage = '$_greenColor📄 Data: $data$_resetColor';
          developer.log(dataMessage, time: now, name: _name, level: 800);
          debugPrint('[$timestamp] $dataMessage');
        }
      });

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) => _runInDebug(() {
    final logTag = tag ?? 'ERROR';
    final now = DateTime.now();
    final timestamp = now.toIso8601String();
    final formattedMessage =
        '$_yellowColor$_boldColor❌ [$logTag] $message$_resetColor';

    developer.log(
      formattedMessage,
      time: now,
      name: _name,
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
    debugPrint('[$timestamp] $formattedMessage');

    if (error != null) {
      final errorMessage = '$_redColor🔥 Error Details: $error$_resetColor';
      developer.log(errorMessage, time: now, name: _name, level: 1000);
      debugPrint('[$timestamp] $errorMessage');
    }
    if (stackTrace != null) {
      debugPrint(
        '[$timestamp] $_redColor📍 Stack Trace: $stackTrace$_resetColor',
      );
    }
  });

  static void info(String message, {String? tag, Object? data}) =>
      _runInDebug(() {
        final logTag = tag ?? 'INFO';
        final now = DateTime.now();
        final timestamp = now.toIso8601String();
        final formattedMessage =
            '$_blueColor$_boldColor💡 [$logTag] $message$_resetColor';

        developer.log(formattedMessage, time: now, name: _name, level: 800);
        debugPrint('[$timestamp] $formattedMessage');

        if (data != null) {
          final dataMessage = '$_blueColor📄 Data: $data$_resetColor';
          developer.log(dataMessage, time: now, name: _name, level: 800);
          debugPrint('[$timestamp] $dataMessage');
        }
      });

  static void api({
    required String method,
    required String endpoint,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Object? requestBody,
    Object? responseData,
    int? statusCode,
    bool isSuccess = true,
  }) => _runInDebug(() {
    final now = DateTime.now();
    final timestamp = now.toIso8601String();
    final color = isSuccess ? _greenColor : _yellowColor;
    final icon = isSuccess ? '📡' : '⚠️';

    final message =
        '$color$_boldColor$icon API $method $endpoint${statusCode != null ? ' ($statusCode)' : ''}$_resetColor';

    developer.log(
      message,
      time: now,
      name: _name,
      level: isSuccess ? 800 : 900,
    );
    debugPrint('[$timestamp] $message');

    if (queryParams != null && queryParams.isNotEmpty) {
      final queryMessage = '$color🔍 Query Params: $queryParams$_resetColor';
      developer.log(queryMessage, name: _name);
      debugPrint('[$timestamp] $queryMessage');
    }

    if (headers != null && headers.isNotEmpty) {
      final headersMessage = '$color📋 Headers: $headers$_resetColor';
      developer.log(headersMessage, name: _name);
      debugPrint('[$timestamp] $headersMessage');
    }

    if (requestBody != null) {
      final bodyMessage = '$color📤 Request Body: $requestBody$_resetColor';
      developer.log(bodyMessage, name: _name);
      debugPrint('[$timestamp] $bodyMessage');
    }

    if (responseData != null) {
      final responseMessage = '$color📥 Response: $responseData$_resetColor';
      developer.log(responseMessage, name: _name);
      debugPrint('[$timestamp] $responseMessage');
    }
  });

  static void pagination(String event, {Object? data}) {
    info(event, tag: 'PAGINATION', data: data);
  }

  static void connectivity(String event, {bool isConnected = true}) {
    final message = isConnected ? 'Connected: $event' : 'Disconnected: $event';
    if (isConnected) {
      success(message, tag: 'CONNECTIVITY');
    } else {
      error(message, tag: 'CONNECTIVITY');
    }
  }

  static void _runInDebug(void Function() action) {
    if (!kDebugMode) return;
    action();
  }
}
