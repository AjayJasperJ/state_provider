/// Singleton for initializing and accessing API host and path config.
class HostServer {
  static String? _baseHost;
  static String? _basePath;
  static bool _initialized = false;

  static String get baseHost {
    if (!_initialized || _baseHost == null) {
      throw Exception(
        'HostServer not initialized. Call HostServer.init() first.',
      );
    }
    return _baseHost!;
  }

  static String get basePath {
    if (!_initialized || _basePath == null) {
      throw Exception(
        'HostServer not initialized. Call HostServer.init() first.',
      );
    }
    return _basePath!;
  }

  static Future<void> init({
    required String baseHost,
    required String basePath,
  }) async {
    _baseHost = baseHost;
    _basePath = basePath;
    _initialized = true;
  }
}
