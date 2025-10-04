enum AppErrorType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  server,
  serialization,
  cancelled,
  unknown,
  unauthenticated,
}

class AppError {
  const AppError({
    required this.type,
    required this.message,
    this.statusCode,
    this.exception,
    this.stackTrace,
  });

  final AppErrorType type;
  final String message;
  final int? statusCode;
  final Object? exception;
  final StackTrace? stackTrace;

  factory AppError.network(Object error, {StackTrace? stackTrace}) {
    return AppError(
      type: AppErrorType.network,
      message: 'Network connection failed. Please check your internet.',
      exception: error,
      stackTrace: stackTrace,
    );
  }

  factory AppError.timeout({StackTrace? stackTrace}) {
    return AppError(
      type: AppErrorType.timeout,
      message: 'The request timed out. Please try again.',
      stackTrace: stackTrace,
    );
  }

  factory AppError.serialization(Object error, {StackTrace? stackTrace}) {
    return AppError(
      type: AppErrorType.serialization,
      message: 'Failed to parse server response.',
      exception: error,
      stackTrace: stackTrace,
    );
  }

  factory AppError.unauthorized({int? statusCode, String? message}) {
    return AppError(
      type: AppErrorType.unauthorized,
      statusCode: statusCode,
      message: message ?? 'You are not authorized to perform this action.',
    );
  }

  factory AppError.forbidden({int? statusCode, String? message}) {
    return AppError(
      type: AppErrorType.forbidden,
      statusCode: statusCode,
      message: message ?? 'You do not have permission to continue.',
    );
  }

  factory AppError.validation(String message, {int? statusCode}) {
    return AppError(
      type: AppErrorType.validation,
      statusCode: statusCode,
      message: message,
    );
  }

  factory AppError.notFound({int? statusCode, String? message}) {
    return AppError(
      type: AppErrorType.notFound,
      statusCode: statusCode,
      message: message ?? "We couldn't find what you're looking for.",
    );
  }

  factory AppError.server({int? statusCode, String? message}) {
    return AppError(
      type: AppErrorType.server,
      statusCode: statusCode,
      message: message ?? 'We had trouble processing your request.',
    );
  }

  factory AppError.cancelled({String? message}) {
    return AppError(
      type: AppErrorType.cancelled,
      message: message ?? 'The request was cancelled.',
    );
  }

  factory AppError.unknown({
    Object? error,
    StackTrace? stackTrace,
    String? message,
    int? statusCode,
  }) {
    return AppError(
      type: AppErrorType.unknown,
      statusCode: statusCode,
      message: message ?? 'Something went wrong. Please try again later.',
      exception: error,
      stackTrace: stackTrace,
    );
  }

  bool get isUnauthorized =>
      type == AppErrorType.unauthorized || type == AppErrorType.unauthenticated;

  @override
  int get hashCode => Object.hash(type, message, statusCode, exception);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppError) return false;
    return type == other.type &&
        message == other.message &&
        statusCode == other.statusCode &&
        exception == other.exception;
  }
}
