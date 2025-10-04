# Core Bootstrap

**Relevant file:** `lib/src/core/bootstrap/state_provider_bootstrap.dart`

## Purpose

`StateProviderBootstrap` centralizes initialization for the services that every consuming app needs before interacting with the rest of the package. It ensures consistent configuration across environments and provides factory helpers for networking.

## Key APIs

| Member | Description | When to use |
| --- | --- | --- |
| `StateProviderBootstrap.initialize({ required String baseHost, required String basePath, bool initializeLogger = true, bool initializeInternetService = true })` | Sets up the global `HostServer`, lazily initializes `LoggerService`, and spins up the shared `InternetService` singleton. | Call once during application startup (e.g., inside `main()` before `runApp`). |
| `StateProviderBootstrap.createApiClient({ http.Client? httpClient, AuthHeadersBuilder? authHeadersBuilder })` | Returns an `ApiClient` configured with the shared host/path, optional custom HTTP client, and authorization header builder. | Use when constructing repositories or data sources that require HTTP access. |

## Usage example

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StateProviderBootstrap.initialize(
    baseHost: 'https://api.example.com',
    basePath: '/v1',
  );

  final client = StateProviderBootstrap.createApiClient(
    authHeadersBuilder: () async => {
      'Authorization': 'Bearer utureAccessToken',
    },
  );

  runApp(MyApp(apiClient: client));
}
```

## Best practices

- Call `initialize` exactly once; repeated calls overwrite global configuration.
- Disable `initializeLogger` or supply a custom sink in environments where file I/O is unsupported (e.g., web) and attach your own logging solution.
- Provide a custom `http.Client` for integration tests or to inject interceptors (e.g., retry, monitoring).
