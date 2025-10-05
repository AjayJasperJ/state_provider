import 'package:http/http.dart' as http;

import '../../data/datasources/api_client.dart';
import '../../data/datasources/host_server.dart';
import '../../data/datasources/internet_service.dart';
import '../../data/datasources/logger_service.dart';

/// Utility helpers to bootstrap the StateProvider toolkit in consuming apps.
class StateProviderBootstrap {
  const StateProviderBootstrap._();

  /// Initializes core services such as [HostServer], [LoggerService], and the
  /// shared [InternetService] singleton.
  static Future<void> initialize({
    required String baseHost,
    required String basePath,
    bool initializeLogger = true,
    bool initializeInternetService = true,
  }) async {
    // Validate inputs
    if (baseHost.isEmpty) {
      throw ArgumentError.value(baseHost, 'baseHost', 'Cannot be empty');
    }
    if (basePath.isEmpty) {
      throw ArgumentError.value(basePath, 'basePath', 'Cannot be empty');
    }

    await HostServer.init(baseHost: baseHost, basePath: basePath);

    if (initializeLogger) {
      await LoggerService.init();
    }

    if (initializeInternetService) {
      InternetService();
    }
  }

  /// Creates a shared [ApiClient] instance configured with app defaults.
  static ApiClient createApiClient({
    http.Client? httpClient,
    AuthHeadersBuilder? authHeadersBuilder,
  }) {
    return ApiClient(
      httpClient: httpClient,
      authHeadersBuilder: authHeadersBuilder,
    );
  }
}
