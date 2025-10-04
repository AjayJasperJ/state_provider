import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../domain/entities/app_error.dart';
import '../../domain/entities/app_result.dart';
import '../../domain/entities/cached_request.dart';
import '../../domain/value_objects/retry_policy.dart';
import '../datasources/api_client.dart';
import '../datasources/internet_service.dart';
import '../datasources/request_cache_store.dart';
import '../../utils/dev_logger.dart';

typedef CachedRequestExecutor =
    Future<AppResult<ApiResponse<Map<String, dynamic>>>> Function(
      CachedRequest request,
    );

/// Coordinates in-memory and persisted cached requests and replays them when
/// connectivity is restored.
class RequestCacheManager extends ChangeNotifier {
  RequestCacheManager._internal({
    RequestCacheStore? store,
    RetryPolicy? retryPolicy,
    int maxConcurrentReplays = 3,
    Duration replayThrottleDelay = const Duration(milliseconds: 500),
  }) : _store = store ?? RequestCacheStore(),
       _retryPolicy = retryPolicy ?? const RetryPolicy(),
       _maxConcurrentReplays = maxConcurrentReplays,
       _replayThrottleDelay = replayThrottleDelay;

  static final RequestCacheManager instance = RequestCacheManager._internal();

  RequestCacheStore _store;
  final RetryPolicy _retryPolicy;
  final Map<String, CachedRequest> _pending = HashMap();
  final int _maxConcurrentReplays;
  final Duration _replayThrottleDelay;

  bool _initialized = false;
  bool _replaying = false;
  int _activeReplays = 0;
  CachedRequestExecutor? _executor;
  InternetService? _internetService;
  VoidCallback? _internetListener;

  RetryPolicy get retryPolicy => _retryPolicy;
  InternetService? get internetService => _internetService;

  List<CachedRequest> get pending =>
      _pending.values.toList(growable: false)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> initialize() async {
    if (_initialized) return;
    final existing = await _store.readAll();
    for (final request in existing) {
      _pending[request.id] = request;
    }
    _initialized = true;
    notifyListeners();
  }

  void registerExecutor(CachedRequestExecutor executor) {
    _executor = executor;
  }

  Future<void> registerInternetService(InternetService service) async {
    await initialize();
    if (_internetService != null && _internetListener != null) {
      _internetService!.removeListener(_internetListener!);
    }
    _internetService = service;
    _internetListener = () {
      if (service.isConnected) {
        // Deduplicate before replaying to prevent API flooding
        unawaited(deduplicateRequests().then((_) => triggerReplay()));
      }
    };
    service.addListener(_internetListener!);
    if (service.isConnected) {
      unawaited(deduplicateRequests().then((_) => triggerReplay()));
    }
  }

  Future<void> resetForTest({
    RequestCacheStore? store,
    bool purgeExistingStore = true,
  }) async {
    if (_internetService != null && _internetListener != null) {
      _internetService!.removeListener(_internetListener!);
    }
    _internetService = null;
    _internetListener = null;
    _executor = null;
    _replaying = false;
    _activeReplays = 0;
    _pending.clear();
    _initialized = false;
    if (store != null) {
      _store = store;
    }
    if (purgeExistingStore) {
      await _store.clear();
    }
    notifyListeners();
  }

  /// Smart deduplication that handles view-only vs persistent requests differently.
  /// - For view requests: keeps only the LATEST (user can only see one detail at a time)
  /// - For pagination/mutations: keeps exact duplicates only (preserve UI state)
  Future<void> deduplicateRequests() async {
    await initialize();

    final viewKeyMap = <String, List<CachedRequest>>{};
    final contentKeyMap = <String, List<CachedRequest>>{};

    // Separate view-only requests from others
    for (final request in _pending.values) {
      if (request.isViewOnlyRequest) {
        final key = request.viewKey;
        viewKeyMap.putIfAbsent(key, () => []).add(request);
      } else {
        final key = request.contentKey;
        contentKeyMap.putIfAbsent(key, () => []).add(request);
      }
    }

    int removedCount = 0;

    // For view-only requests: keep ONLY the latest per view group
    // (user tapped item A, then B, then C - only keep C, discard A and B)
    for (final entry in viewKeyMap.entries) {
      final requests = entry.value;
      if (requests.length <= 1) continue;

      // Sort by creation time, keep ONLY the most recent
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final toKeep = requests.first;
      final toRemove = requests.skip(1);

      for (final request in toRemove) {
        await _remove(request.id);
        removedCount++;
      }

      DevLogger.cache(
        'View-only deduplication (last-only)',
        data: {
          'viewKey': entry.key,
          'originalCount': requests.length,
          'removedCount': toRemove.length,
          'keptRequestId': toKeep.id,
        },
      );
    }

    // For non-view requests (pagination, mutations): only remove exact duplicates
    for (final entry in contentKeyMap.entries) {
      final requests = entry.value;
      if (requests.length <= 1) continue;

      // Keep the most recent of identical requests
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final toKeep = requests.first;
      final toRemove = requests.skip(1);

      for (final request in toRemove) {
        await _remove(request.id);
        removedCount++;
      }

      DevLogger.cache(
        'Exact duplicate removal',
        data: {
          'contentKey': entry.key,
          'originalCount': requests.length,
          'removedCount': toRemove.length,
          'keptRequestId': toKeep.id,
        },
      );
    }

    if (removedCount > 0) {
      DevLogger.cache(
        'Smart deduplication complete',
        data: {
          'totalRemoved': removedCount,
          'remainingRequests': _pending.length,
        },
      );
      notifyListeners();
    }
  }

  /// Find an existing request with the same content to avoid duplicates.
  /// Returns null if no duplicate is found.
  CachedRequest? _findDuplicateRequest(CachedRequest newRequest) {
    for (final existingRequest in _pending.values) {
      if (existingRequest.contentKey == newRequest.contentKey) {
        DevLogger.cache(
          'Duplicate request detected and prevented',
          data: {
            'method': newRequest.method,
            'path': newRequest.path,
            'existingRequestId': existingRequest.id,
            'newRequestId': newRequest.id,
          },
        );
        return existingRequest;
      }
    }
    return null;
  }

  Future<AppResult<ApiResponse<Map<String, dynamic>>>> enqueueAndExecute(
    CachedRequest request,
    Future<AppResult<ApiResponse<Map<String, dynamic>>>> Function(
      CachedRequest request,
    )
    send, {
    required bool connected,
  }) async {
    await initialize();

    // Check for existing request with same content to avoid duplication
    final existingRequest = _findDuplicateRequest(request);
    if (existingRequest != null) {
      // Use existing request instead of creating duplicate
      if (!connected) {
        return AppFailure(
          AppError.network(Exception('No internet connection')),
        );
      }
      // Execute the existing request if we're connected
      return _execute(existingRequest, send);
    }

    // No duplicate found, proceed with new request
    DevLogger.cache(
      'Adding new request to cache',
      data: {'method': request.method, 'path': request.path, 'id': request.id},
    );
    _pending[request.id] = request;
    await _store.upsert(request);
    notifyListeners();

    if (!connected) {
      return AppFailure(AppError.network(Exception('No internet connection')));
    }

    return _execute(request, send);
  }

  Future<AppResult<ApiResponse<Map<String, dynamic>>>> triggerReplay() async {
    await initialize();
    if (_replaying) {
      return const AppSuccess(
        ApiResponse(data: <String, dynamic>{}, statusCode: 200),
      );
    }
    if (_executor == null) {
      return AppFailure(
        AppError.unknown(message: 'Request executor not configured'),
      );
    }
    if (_internetService != null && !_internetService!.isConnected) {
      return AppFailure(AppError.network(Exception('Offline')));
    }

    _replaying = true;
    _activeReplays = 0;

    try {
      final now = DateTime.now();
      final readyRequests = pending
          .where((request) => request.isReadyForReplay(now))
          .toList();

      DevLogger.cache(
        'Starting throttled replay',
        data: {
          'totalPending': pending.length,
          'readyForReplay': readyRequests.length,
          'maxConcurrent': _maxConcurrentReplays,
        },
      );

      // Process requests in batches to avoid API flooding
      for (int i = 0; i < readyRequests.length; i += _maxConcurrentReplays) {
        final batch = readyRequests.skip(i).take(_maxConcurrentReplays);
        final futures = <Future<void>>[];

        for (final request in batch) {
          if (!request.hasAttemptsRemaining) {
            futures.add(_remove(request.id));
            continue;
          }

          _activeReplays++;
          futures.add(_executeWithThrottle(request, _executor!));
        }

        // Wait for current batch to complete before starting next batch
        await Future.wait(futures);

        // Check connectivity between batches
        if (_internetService != null && !_internetService!.isConnected) {
          DevLogger.cache('Replay interrupted - connection lost');
          break;
        }

        // Add delay between batches to prevent overwhelming the API
        if (i + _maxConcurrentReplays < readyRequests.length) {
          await Future.delayed(_replayThrottleDelay);
        }
      }
    } finally {
      _replaying = false;
      _activeReplays = 0;
      notifyListeners();
    }
    return const AppSuccess(
      ApiResponse(data: <String, dynamic>{}, statusCode: 200),
    );
  }

  /// Execute a request with throttling and proper cleanup
  Future<void> _executeWithThrottle(
    CachedRequest request,
    CachedRequestExecutor executor,
  ) async {
    try {
      await _execute(request, executor);
    } catch (error) {
      DevLogger.cache(
        'Error during throttled replay',
        data: {'requestId': request.id, 'error': error.toString()},
      );
    } finally {
      _activeReplays = (_activeReplays - 1).clamp(0, _maxConcurrentReplays);
    }
  }

  Future<AppResult<ApiResponse<Map<String, dynamic>>>> _execute(
    CachedRequest request,
    Future<AppResult<ApiResponse<Map<String, dynamic>>>> Function(CachedRequest)
    send,
  ) async {
    final attemptNumber = request.attempt + 1;
    final updatedRequest = request.copyWith(attempt: attemptNumber);
    _pending[request.id] = updatedRequest;
    await _store.upsert(updatedRequest);

    final result = await send(updatedRequest);
    await _handleResult(updatedRequest, result);
    return result;
  }

  Future<void> _handleResult(
    CachedRequest request,
    AppResult<ApiResponse<Map<String, dynamic>>> result,
  ) async {
    if (result.isSuccess) {
      await _remove(request.id);
      return;
    }

    final error = result.asFailure.error;
    if (_retryPolicy.shouldRetry(error, request.attempt)) {
      final backoff = _retryPolicy.backoffForAttempt(request.attempt);
      final nextRetryAt = DateTime.now().add(backoff);
      final updated = request.copyWith(nextRetryAt: nextRetryAt);
      _pending[updated.id] = updated;
      await _store.upsert(updated);
      notifyListeners();
    } else {
      await _remove(request.id);
    }
  }

  Future<void> _remove(String id) async {
    _pending.remove(id);
    await _store.remove(id);
    notifyListeners();
  }

  @override
  void dispose() {
    if (_internetService != null && _internetListener != null) {
      _internetService!.removeListener(_internetListener!);
    }
    super.dispose();
  }
}
