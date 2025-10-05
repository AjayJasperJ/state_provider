/// Singleton for initializing and accessing API host and path config.
class HostServer {
  static String? _baseHost;
  static String? _basePath;
  static bool _initialized = false;

  static String get baseHost {
    _assertInitialized();
    return _baseHost!;
  }

  static String get basePath {
    _assertInitialized();
    return _basePath!;
  }

  static void _assertInitialized() {
    if (!_initialized) {
      throw Exception(
        'HostServer not initialized. Call HostServer.init() first.',
      );
    }
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
