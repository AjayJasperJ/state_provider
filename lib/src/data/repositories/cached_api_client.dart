import 'dart:async';
import 'dart:math';

import '../../domain/entities/app_error.dart';
import '../../domain/entities/app_result.dart';
import '../../domain/entities/cached_request.dart';
import '../datasources/api_client.dart';
import '../datasources/internet_service.dart';
import 'request_cache_manager.dart';

class CachedApiClient extends ApiClient {
  CachedApiClient({
    super.httpClient,
    RequestCacheManager? cacheManager,
    InternetService? internetService,
    bool enableCaching = true,
    bool autoRegisterInternetService = true,
    this.isConnectedOverride,
  }) : _cacheManager = cacheManager ?? RequestCacheManager.instance,
       _enableCaching = enableCaching,
       _random = Random() {
    _cacheManager.registerExecutor(_executeCachedRequest);
    if (autoRegisterInternetService) {
      final service =
          internetService ?? _cacheManager.internetService ?? InternetService();
      unawaited(_cacheManager.registerInternetService(service));
    } else if (internetService != null) {
      unawaited(_cacheManager.registerInternetService(internetService));
    }
  }

  static const _methodGetJson = 'GET_JSON';
  static const _methodPostJson = 'POST_JSON';

  final RequestCacheManager _cacheManager;
  final bool _enableCaching;
  final Random _random;
  final bool Function()? isConnectedOverride;

  String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  @override
  Future<AppResult<ApiResponse<Map<String, dynamic>>>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
    Map<String, String>? headers,
    String? logKey,
  }) {
    if (!_enableCaching) {
      return super.getJson(
        path,
        queryParameters: queryParameters,
        authenticated: authenticated,
        headers: headers,
        logKey: logKey,
      );
    }

    final request = CachedRequest(
      id: _generateId(),
      method: _methodGetJson,
      path: path,
      queryParameters: queryParameters,
      headers: headers,
      authenticated: authenticated,
      jsonBody: null,
      formBody: null,
      attempt: 0,
      maxAttempts: _cacheManager.retryPolicy.maxAttempts,
      createdAt: DateTime.now(),
      nextRetryAt: null,
      logKey: logKey,
    );

    final connected =
        isConnectedOverride?.call() ??
        _cacheManager.internetService?.isConnected ??
        true;
    return _cacheManager.enqueueAndExecute(
      request,
      (_) => super.getJson(
        path,
        queryParameters: queryParameters,
        authenticated: authenticated,
        headers: headers,
        logKey: logKey,
      ),
      connected: connected,
    );
  }

  @override
  Future<AppResult<ApiResponse<Map<String, dynamic>>>> postJson(
    String path, {
    Map<String, dynamic>? jsonBody,
    Map<String, String>? formBody,
    bool authenticated = true,
    Map<String, String>? headers,
    String? logKey,
  }) {
    if (!_enableCaching) {
      return super.postJson(
        path,
        jsonBody: jsonBody,
        formBody: formBody,
        authenticated: authenticated,
        headers: headers,
        logKey: logKey,
      );
    }

    final request = CachedRequest(
      id: _generateId(),
      method: _methodPostJson,
      path: path,
      headers: headers,
      queryParameters: null,
      jsonBody: jsonBody,
      formBody: formBody,
      authenticated: authenticated,
      attempt: 0,
      maxAttempts: _cacheManager.retryPolicy.maxAttempts,
      createdAt: DateTime.now(),
      nextRetryAt: null,
      logKey: logKey,
    );

    final connected =
        isConnectedOverride?.call() ??
        _cacheManager.internetService?.isConnected ??
        true;
    return _cacheManager.enqueueAndExecute(
      request,
      (_) => super.postJson(
        path,
        jsonBody: jsonBody,
        formBody: formBody,
        authenticated: authenticated,
        headers: headers,
        logKey: logKey,
      ),
      connected: connected,
    );
  }

  Future<AppResult<ApiResponse<Map<String, dynamic>>>> _executeCachedRequest(
    CachedRequest request,
  ) {
    switch (request.method) {
      case _methodGetJson:
        return super.getJson(
          request.path,
          queryParameters: request.queryParameters,
          authenticated: request.authenticated,
          headers: request.headers,
          logKey: request.logKey,
        );
      case _methodPostJson:
        return super.postJson(
          request.path,
          jsonBody: request.jsonBody,
          formBody: request.formBody,
          authenticated: request.authenticated,
          headers: request.headers,
          logKey: request.logKey,
        );
      default:
        return Future.value(
          AppFailure(
            AppError.unknown(
              message: 'Unsupported cached method: ${request.method}',
            ),
          ),
        );
    }
  }
}
