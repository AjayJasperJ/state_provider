import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../../state_provider.dart';

class ApiResponse<T> {
  const ApiResponse({required this.data, required this.statusCode, this.raw});

  final T data;
  final int statusCode;
  final http.Response? raw;
}

typedef AuthHeadersBuilder = FutureOr<Map<String, String>> Function();

class ApiClient {
  ApiClient({http.Client? httpClient, AuthHeadersBuilder? authHeadersBuilder})
    : _httpClient = httpClient ?? http.Client(),
      _authHeadersBuilder = authHeadersBuilder;

  final http.Client _httpClient;
  final AuthHeadersBuilder? _authHeadersBuilder;

  Future<AppResult<ApiResponse<Map<String, dynamic>>>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
    Map<String, String>? headers,
    String? logKey,
  }) async {
    return _executeRequest(
      () async {
        final uri = _buildUri(path, queryParameters);
        final combinedHeaders = await _buildHeaders(
          authenticated: authenticated,
          additional: headers,
        );
        return _httpClient.get(uri, headers: combinedHeaders);
      },
      logKey: logKey,
      request: {
        'method': 'GET',
        'path': path,
        if (queryParameters != null && queryParameters.isNotEmpty)
          'query': queryParameters,
      },
    );
  }

  Future<AppResult<ApiResponse<Map<String, dynamic>>>> postJson(
    String path, {
    Map<String, dynamic>? jsonBody,
    Map<String, String>? formBody,
    bool authenticated = true,
    Map<String, String>? headers,
    String? logKey,
  }) async {
    assert(
      jsonBody == null || formBody == null,
      'Provide either jsonBody or formBody, not both',
    );

    return _executeRequest(
      () async {
        final uri = _buildUri(path, null);
        final combinedHeaders = await _buildHeaders(
          authenticated: authenticated,
          additional: headers,
          contentType: jsonBody != null
              ? 'application/json'
              : 'application/x-www-form-urlencoded',
        );

        final body = jsonBody != null ? jsonEncode(jsonBody) : formBody;
        return _httpClient.post(uri, headers: combinedHeaders, body: body);
      },
      logKey: logKey,
      request: {
        'method': 'POST',
        'path': path,
        if (jsonBody != null) 'body': jsonBody,
        if (formBody != null) 'body': formBody,
      },
    );
  }

  Future<AppResult<ApiResponse<Map<String, dynamic>>>> sendMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, String>? headers,
    bool authenticated = true,
    Map<String, http.MultipartFile>? files,
    String? logKey,
  }) async {
    return _executeRequest(
      () async {
        final uri = _buildUri(path, null);
        final request = http.MultipartRequest('POST', uri);
        final combinedHeaders = await _buildHeaders(
          authenticated: authenticated,
          additional: headers,
        );
        request.headers.addAll(combinedHeaders);
        request.fields.addAll(fields);
        if (files != null && files.isNotEmpty) {
          request.files.addAll(files.values);
        }

        final streamedResponse = await request.send();
        return http.Response.fromStream(streamedResponse);
      },
      logKey: logKey,
      request: {
        'method': 'POST_MULTIPART',
        'path': path,
        'fields': fields,
        if (files != null) 'files': files.keys.toList(),
      },
    );
  }

  Future<AppResult<ApiResponse<Map<String, dynamic>>>> _executeRequest(
    Future<http.Response> Function() requestFunction, {
    String? logKey,
    Map<String, Object?>? request,
  }) async {
    try {
      final response = await requestFunction();
      return _handleResponse(response, logKey: logKey, request: request);
    } on SocketException catch (error, stackTrace) {
      await _logFailure(logKey, error: error, stackTrace: stackTrace);
      return AppFailure(ApiErrorFactory.network(error, stackTrace: stackTrace));
    } on TimeoutException catch (error, stackTrace) {
      await _logFailure(logKey, error: error, stackTrace: stackTrace);
      return AppFailure(ApiErrorFactory.timeout(stackTrace: stackTrace));
    } catch (error, stackTrace) {
      await _logFailure(logKey, error: error, stackTrace: stackTrace);
      return AppFailure(
        ApiErrorFactory.unknown(error: error, stackTrace: stackTrace),
      );
    }
  }

  Future<Map<String, String>> _buildHeaders({
    required bool authenticated,
    Map<String, String>? additional,
    String? contentType,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};

    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }

    if (authenticated && _authHeadersBuilder != null) {
      final authHeaders = await _authHeadersBuilder();
      if (authHeaders.isNotEmpty) {
        headers.addAll(authHeaders);
      }
    }
    if (additional != null && additional.isNotEmpty) {
      headers.addAll(additional);
    }

    return headers;
  }

  Uri _buildUri(String path, Map<String, String>? queryParameters) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final uri = Uri.parse(path);
      if (queryParameters == null || queryParameters.isEmpty) {
        return uri;
      }
      final mergedParams = <String, String>{
        ...uri.queryParameters,
        ...queryParameters,
      };
      return uri.replace(queryParameters: mergedParams);
    }

    // Relative path - compose with HostServer values.
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final fullPath = HostServer.basePath + normalizedPath;
    final uri = Uri.parse('${HostServer.baseHost}$fullPath');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: queryParameters);
  }

  Future<AppResult<ApiResponse<Map<String, dynamic>>>> _handleResponse(
    http.Response response, {
    String? logKey,
    Map<String, Object?>? request,
  }) async {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      Map<String, dynamic> jsonBody;
      try {
        jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (error, stackTrace) {
        await _logFailure(logKey, error: error, stackTrace: stackTrace);
        return AppFailure(
          ApiErrorFactory.serialization(error, stackTrace: stackTrace),
        );
      }

      final apiResponse = ApiResponse(
        data: jsonBody,
        statusCode: statusCode,
        raw: response,
      );

      await _logSuccess(
        logKey,
        request: request,
        response: jsonBody,
        status: statusCode,
      );

      return AppSuccess(apiResponse);
    }

    // Error response
    Map<String, dynamic>? jsonBody;
    try {
      jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Ignore parsing errors for error responses
    }

    final message = mapErrorMessage(
      statusCode: statusCode,
      fallback: jsonBody?['message']?.toString(),
    );

    final error = ApiErrorFactory.fromStatusCode(statusCode, message: message);
    await _logFailure(
      logKey,
      request: request,
      statusCode: statusCode,
      response: jsonBody,
      error: error,
    );

    return AppFailure(error);
  }

  Future<void> _logSuccess(
    String? logKey, {
    Map<String, Object?>? request,
    Object? response,
    int? status,
  }) async {
    if (logKey == null) return;
    await LoggerService.logApi(
      logKey,
      request: request as Map<String, dynamic>?,
      response: {'data': response},
      statusCode: status,
      success: true,
    );
  }

  Future<void> _logFailure(
    String? logKey, {
    Object? error,
    StackTrace? stackTrace,
    Object? response,
    Map<String, Object?>? request,
    int? statusCode,
  }) async {
    if (logKey == null) return;
    await LoggerService.logApi(
      logKey,
      success: false,
      statusCode: statusCode,
      request: request as Map<String, dynamic>?,
      response: {
        'error': error?.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        if (response != null) 'payload': response,
      },
    );
  }

  void dispose() {
    _httpClient.close();
  }
}

class ApiErrorFactory {
  const ApiErrorFactory._();

  static AppError fromStatusCode(int statusCode, {String? message}) {
    switch (statusCode) {
      case 400:
        return AppError.validation(message ?? 'Invalid request.');
      case 401:
        return AppError.unauthorized(statusCode: statusCode, message: message);
      case 403:
        return AppError.forbidden(statusCode: statusCode, message: message);
      case 404:
        return AppError.notFound(statusCode: statusCode, message: message);
      case 408:
        return AppError.timeout();
      case 422:
        return AppError.validation(message ?? 'Validation error');
      case 429:
        return AppError.validation(message ?? 'Too many requests.');
      case 500:
      case 501:
      case 502:
      case 503:
      case 504:
        return AppError.server(statusCode: statusCode, message: message);
      default:
        return AppError.unknown(statusCode: statusCode, message: message);
    }
  }

  static AppError network(Object error, {StackTrace? stackTrace}) =>
      AppError.network(error, stackTrace: stackTrace);

  static AppError timeout({StackTrace? stackTrace}) =>
      AppError.timeout(stackTrace: stackTrace);

  static AppError serialization(Object error, {StackTrace? stackTrace}) =>
      AppError.serialization(error, stackTrace: stackTrace);

  static AppError unknown({Object? error, StackTrace? stackTrace}) =>
      AppError.unknown(error: error, stackTrace: stackTrace);
}
