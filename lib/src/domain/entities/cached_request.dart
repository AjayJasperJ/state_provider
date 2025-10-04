import 'dart:convert';

/// Represents a network call that has been captured for retry when the
/// connection is restored or a transient failure occurs.
class CachedRequest {
  const CachedRequest({
    required this.id,
    required this.method,
    required this.path,
    this.queryParameters,
    this.headers,
    this.jsonBody,
    this.formBody,
    required this.authenticated,
    required this.attempt,
    required this.maxAttempts,
    required this.createdAt,
    this.nextRetryAt,
    this.logKey,
  });

  /// Unique identifier for the cached request.
  final String id;

  /// Method descriptor understood by the [CachedApiClient].
  /// Examples: `GET_JSON`, `POST_JSON`.
  final String method;

  /// Relative or absolute path originally sent to [ApiClient].
  final String path;

  /// Query parameters used during the request.
  final Map<String, String>? queryParameters;

  /// Headers to be merged when replaying the request.
  final Map<String, String>? headers;

  /// JSON body payload for POST/PUT style calls.
  final Map<String, dynamic>? jsonBody;

  /// Form body for `application/x-www-form-urlencoded` requests.
  final Map<String, String>? formBody;

  /// Whether the request should include authentication headers.
  final bool authenticated;

  /// Current attempt count.
  final int attempt;

  /// Allowed maximum attempts (initial + retries).
  final int maxAttempts;

  /// Timestamp when the request was first created.
  final DateTime createdAt;

  /// Optional timestamp after which the request can be replayed.
  final DateTime? nextRetryAt;

  /// Optional log key forwarded to [LoggerService].
  final String? logKey;

  bool get hasAttemptsRemaining => attempt < maxAttempts;

  bool isReadyForReplay(DateTime now) =>
      nextRetryAt == null || now.isAfter(nextRetryAt!);

  /// Generate a content-based key for duplicate detection.
  /// Two requests with the same content key are considered duplicates.
  String get contentKey {
    final components = [
      method,
      path,
      queryParameters?.toString() ?? '',
      headers?.toString() ?? '',
      jsonBody?.toString() ?? '',
      formBody?.toString() ?? '',
      authenticated.toString(),
    ];
    return components.join('|');
  }

  /// Generate a view-based key for last-only deduplication.
  /// Groups requests by endpoint pattern, ignoring specific IDs for view requests.
  String get viewKey {
    // For GET requests that look like detail views (/items/123, /users/456),
    // group them by the base pattern (/items/*, /users/*)
    if (method.startsWith('GET') && path.contains(RegExp(r'/\d+(\?|$)'))) {
      // Replace ID segments with wildcard for grouping
      final normalizedPath = path.replaceAll(RegExp(r'/\d+'), '/*');
      return 'GET:$normalizedPath';
    }

    // For pagination requests, include page info to avoid grouping different pages
    if (method.startsWith('GET') && queryParameters != null) {
      final page = queryParameters!['page'];
      final limit = queryParameters!['limit'];
      if (page != null || limit != null) {
        return 'PAGINATED:$path:page=$page:limit=$limit';
      }
    }

    // For other requests (POST, PUT, DELETE), use full content key
    return contentKey;
  }

  /// Determines if this request represents a view-only operation that should
  /// be last-only deduplicated (only keep the most recent).
  bool get isViewOnlyRequest {
    // GET requests to detail endpoints (contains ID in path)
    if (method.startsWith('GET') && path.contains(RegExp(r'/\d+(\?|$)'))) {
      return true;
    }

    // GET requests without pagination parameters
    if (method.startsWith('GET') && queryParameters != null) {
      final hasPagination =
          queryParameters!.containsKey('page') ||
          queryParameters!.containsKey('limit') ||
          queryParameters!.containsKey('offset');
      return !hasPagination;
    }

    // Simple GET requests
    return method.startsWith('GET');
  }

  CachedRequest copyWith({int? attempt, DateTime? nextRetryAt}) {
    return CachedRequest(
      id: id,
      method: method,
      path: path,
      queryParameters: queryParameters,
      headers: headers,
      jsonBody: jsonBody,
      formBody: formBody,
      authenticated: authenticated,
      attempt: attempt ?? this.attempt,
      maxAttempts: maxAttempts,
      createdAt: createdAt,
      nextRetryAt: nextRetryAt,
      logKey: logKey,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'method': method,
      'path': path,
      'queryParameters': queryParameters,
      'headers': headers,
      'jsonBody': jsonBody,
      'formBody': formBody,
      'authenticated': authenticated,
      'attempt': attempt,
      'maxAttempts': maxAttempts,
      'createdAt': createdAt.toIso8601String(),
      'nextRetryAt': nextRetryAt?.toIso8601String(),
      'logKey': logKey,
    };
  }

  factory CachedRequest.fromJson(Map<String, Object?> json) {
    Map<String, String>? decodeStringMap(Object? value) {
      if (value == null) return null;
      return Map<String, String>.from(value as Map);
    }

    Map<String, dynamic>? decodeJsonMap(Object? value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      if (value is String) {
        return jsonDecode(value) as Map<String, dynamic>;
      }
      return null;
    }

    return CachedRequest(
      id: json['id'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      queryParameters: decodeStringMap(json['queryParameters']),
      headers: decodeStringMap(json['headers']),
      jsonBody: decodeJsonMap(json['jsonBody']),
      formBody: decodeStringMap(json['formBody']),
      authenticated: json['authenticated'] as bool? ?? true,
      attempt: json['attempt'] as int? ?? 0,
      maxAttempts: json['maxAttempts'] as int? ?? 3,
      createdAt: DateTime.parse(json['createdAt'] as String),
      nextRetryAt: json['nextRetryAt'] == null
          ? null
          : DateTime.parse(json['nextRetryAt'] as String),
      logKey: json['logKey'] as String?,
    );
  }
}
