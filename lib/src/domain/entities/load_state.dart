import 'app_error.dart';

class LoadState<T> {
  const LoadState({this.data, this.error, this.isLoading = false});

  final T? data;
  final AppError? error;
  final bool isLoading;

  bool get hasData => data != null;
  bool get hasError => error != null;

  LoadState<T> copyWith({
    T? data,
    AppError? error,
    bool? isLoading,
    bool clearError = false,
  }) {
    return LoadState<T>(
      data: data ?? this.data,
      error: clearError ? null : error ?? this.error,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static LoadState<T> idle<T>({T? data}) => LoadState<T>(data: data);

  static LoadState<T> loading<T>({T? data}) =>
      LoadState<T>(isLoading: true, data: data);

  static LoadState<T> success<T>(T data) => LoadState<T>(data: data);

  static LoadState<T> failure<T>(AppError error, {T? data}) =>
      LoadState<T>(error: error, data: data);
}
