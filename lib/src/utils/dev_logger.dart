import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Developer logger with colored console output
/// Only logs in debug mode for development purposes
class DevLogger {
  static const String _name = 'DevLogger';

  // ANSI color codes for terminal output
  static const String _greenColor = '\x1B[32m'; // Green
  static const String _yellowColor = '\x1B[33m'; // Yellow
  static const String _redColor = '\x1B[31m'; // Red
  static const String _blueColor = '\x1B[34m'; // Blue
  static const String _resetColor = '\x1B[0m'; // Reset
  static const String _boldColor = '\x1B[1m'; // Bold

  /// Log a success message in green color
  static void success(String message, {String? tag, Object? data}) {
    if (!kDebugMode) return;

    final String logTag = tag ?? 'SUCCESS';
    final String timestamp = DateTime.now().toIso8601String();
    final String formattedMessage =
        '$_greenColor$_boldColor✅ [$logTag] $message$_resetColor';

    developer.log(
      formattedMessage,
      time: DateTime.now(),
      name: _name,
      level: 800, // Info level
    );

    if (data != null) {
      developer.log(
        '$_greenColor📄 Data: $data$_resetColor',
        time: DateTime.now(),
        name: _name,
        level: 800,
      );
    }

    // Also print to console for better visibility during development
    debugPrint('[$timestamp] $formattedMessage');
    if (data != null) {
      debugPrint('[$timestamp] $_greenColor📄 Data: $data$_resetColor');
    }
  }

  /// Log an error message in yellow/red color
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;

    final String logTag = tag ?? 'ERROR';
    final String timestamp = DateTime.now().toIso8601String();
    final String formattedMessage =
        '$_yellowColor$_boldColor❌ [$logTag] $message$_resetColor';

    developer.log(
      formattedMessage,
      time: DateTime.now(),
      name: _name,
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );

    if (error != null) {
      developer.log(
        '$_redColor🔥 Error Details: $error$_resetColor',
        time: DateTime.now(),
        name: _name,
        level: 1000,
      );
    }

    // Also print to console for better visibility during development
    debugPrint('[$timestamp] $formattedMessage');
    if (error != null) {
      debugPrint('[$timestamp] $_redColor🔥 Error Details: $error$_resetColor');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint(
        '[$timestamp] $_redColor📍 Stack Trace: $stackTrace$_resetColor',
      );
    }
  }

  /// Log an info message in blue color
  static void info(String message, {String? tag, Object? data}) {
    if (!kDebugMode) return;

    final String logTag = tag ?? 'INFO';
    final String timestamp = DateTime.now().toIso8601String();
    final String formattedMessage =
        '$_blueColor$_boldColor💡 [$logTag] $message$_resetColor';

    developer.log(
      formattedMessage,
      time: DateTime.now(),
      name: _name,
      level: 800,
    );

    if (data != null) {
      developer.log(
        '$_blueColor📄 Data: $data$_resetColor',
        time: DateTime.now(),
        name: _name,
        level: 800,
      );
    }

    // Also print to console for better visibility during development
    debugPrint('[$timestamp] $formattedMessage');
    if (data != null) {
      debugPrint('[$timestamp] $_blueColor📄 Data: $data$_resetColor');
    }
  }

  /// Log API requests and responses
  static void api({
    required String method,
    required String endpoint,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Object? requestBody,
    Object? responseData,
    int? statusCode,
    bool isSuccess = true,
  }) {
    if (!kDebugMode) return;

    final String timestamp = DateTime.now().toIso8601String();
    final String color = isSuccess ? _greenColor : _yellowColor;
    final String icon = isSuccess ? '📡' : '⚠️';

    final String message =
        '$color$_boldColor$icon API $method $endpoint${statusCode != null ? ' ($statusCode)' : ''}$_resetColor';

    developer.log(
      message,
      time: DateTime.now(),
      name: _name,
      level: isSuccess ? 800 : 900,
    );

    // Log additional details
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
  }

  /// Log pagination events
  static void pagination(String event, {Object? data}) {
    info(event, tag: 'PAGINATION', data: data);
  }

  /// Log connectivity events
  static void connectivity(String event, {bool isConnected = true}) {
    final String message = isConnected
        ? 'Connected: $event'
        : 'Disconnected: $event';

    if (isConnected) {
      success(message, tag: 'CONNECTIVITY');
    } else {
      error(message, tag: 'CONNECTIVITY');
    }
  }

  /// Log cache events
  static void cache(String event, {Object? data}) {
    info(event, tag: 'CACHE', data: data);
  }
}
