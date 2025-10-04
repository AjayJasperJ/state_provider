import 'app_error.dart';

sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => this is AppSuccess<T>;
  bool get isFailure => this is AppFailure<T>;

  AppSuccess<T> get asSuccess => this as AppSuccess<T>;
  AppFailure<T> get asFailure => this as AppFailure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    final self = this;
    if (self is AppSuccess<T>) {
      return success(self.data);
    }
    return failure((self as AppFailure<T>).error);
  }

  AppResult<R> map<R>(R Function(T data) transform) {
    final self = this;
    if (self is AppSuccess<T>) {
      return AppSuccess<R>(transform(self.data));
    }
    return AppFailure<R>((self as AppFailure<T>).error);
  }
}

class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.data);
  final T data;
}

class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.error);
  final AppError error;
}
