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

        if (data != null) {
          developer.log(
            '$_greenColor📄 Data: $data$_resetColor',
            time: now,
            name: _name,
            level: 800,
          );
        }

        debugPrint('[$timestamp] $formattedMessage');
        if (data != null) {
          debugPrint('[$timestamp] $_greenColor📄 Data: $data$_resetColor');
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

    if (error != null) {
      developer.log(
        '$_redColor🔥 Error Details: $error$_resetColor',
        time: now,
        name: _name,
        level: 1000,
      );
    }

    debugPrint('[$timestamp] $formattedMessage');
    if (error != null) {
      debugPrint('[$timestamp] $_redColor🔥 Error Details: $error$_resetColor');
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

        if (data != null) {
          developer.log(
            '$_blueColor📄 Data: $data$_resetColor',
            time: now,
            name: _name,
            level: 800,
          );
        }

        debugPrint('[$timestamp] $formattedMessage');
        if (data != null) {
          debugPrint('[$timestamp] $_blueColor📄 Data: $data$_resetColor');
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

    if (queryParams != null && queryParams.isNotEmpty) {
      developer.log(
        '$color🔍 Query Params: $queryParams$_resetColor',
        name: _name,
      );
      debugPrint(
        '[$timestamp] $color🔍 Query Params: $queryParams$_resetColor',
      );
    }

    if (headers != null && headers.isNotEmpty) {
      developer.log('$color📋 Headers: $headers$_resetColor', name: _name);
      debugPrint('[$timestamp] $color📋 Headers: $headers$_resetColor');
    }

    if (requestBody != null) {
      developer.log(
        '$color📤 Request Body: $requestBody$_resetColor',
        name: _name,
      );
      debugPrint(
        '[$timestamp] $color📤 Request Body: $requestBody$_resetColor',
      );
    }

    if (responseData != null) {
      developer.log(
        '$color📥 Response: $responseData$_resetColor',
        name: _name,
      );
      debugPrint('[$timestamp] $color📥 Response: $responseData$_resetColor');
    }

    debugPrint('[$timestamp] $message');
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
