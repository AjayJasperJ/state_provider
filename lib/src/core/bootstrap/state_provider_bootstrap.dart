import '../../data/datasources/host_server.dart';
import '../../data/datasources/internet_service.dart';
import '../../data/datasources/logger_service.dart';
import '../../data/repositories/cached_api_client.dart';
import '../../data/repositories/request_cache_manager.dart';

/// Utility helpers to bootstrap the StateProvider toolkit in consuming apps.
class StateProviderBootstrap {
  const StateProviderBootstrap._();

  /// Initializes core services such as [HostServer], [LoggerService], and the
  /// request caching infrastructure.
  static Future<void> initialize({
    required String baseHost,
    required String basePath,
    bool initializeLogger = true,
    bool enableCaching = true,
  }) async {
    await HostServer.init(baseHost: baseHost, basePath: basePath);

    if (initializeLogger) {
      await LoggerService.init();
    }

    if (enableCaching) {
      final internetService = InternetService();
      await RequestCacheManager.instance.registerInternetService(
        internetService,
      );
    }
  }

  /// Creates an [CachedApiClient] hooked into the shared request cache.
  static CachedApiClient createApiClient({bool enableCaching = true}) {
    return CachedApiClient(enableCaching: enableCaching);
  }
}
