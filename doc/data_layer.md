# Data Layer

**Files covered:**

- `lib/src/data/datasources/api_client.dart`
- `lib/src/data/datasources/host_server.dart`
- `lib/src/data/datasources/internet_service.dart`
- `lib/src/data/datasources/logger_service.dart`

## `api_client.dart`

### What it does
A strongly-typed HTTP client that wraps `package:http` and returns `AppResult<ApiResponse<Map<String, dynamic>>>`. It handles URI composition, header management, success parsing, and rich error mapping.

### Key members
| Member | Description | When to use |
| --- | --- | --- |
| `getJson()` | Issues a GET request and parses the JSON body. | Fetch list/detail resources. |
| `postJson()` | Sends JSON or form data, automatically setting headers. | Create/update resources. |
| `sendMultipart()` | Handles multipart uploads with file attachments. | Upload files or media assets. |
| `dispose()` | Closes the underlying `http.Client`. | Call when you own the client lifecycle (e.g., in tests). |

### Error handling
All failures map to `AppError` using `ApiErrorFactory`, providing typed failures (`network`, `timeout`, `server`, etc.). Attach a `logKey` to enable structured request/response logging through `LoggerService`.

---

## `host_server.dart`

Singleton storing the base host and path for all relative API calls. `StateProviderBootstrap.initialize` sets these values.

- `HostServer.init({required String baseHost, required String basePath})`: call during bootstrap.
- `HostServer.baseHost`, `HostServer.basePath`: throw if accessed before initialization, ensuring you configure the host.

Use this to avoid hard-coding hosts across clients.

---

## `internet_service.dart`

Provides connectivity awareness and exposes a `ChangeNotifier` that widgets can observe. Typical usage flows through `ConnectivityWrapper` (see presentation docs).

- Creates a singleton `InternetService` when constructed.
- Listens to connectivity changes via `connectivity_plus` and notifies listeners.
- Ideal for building global offline banners or retry prompts.

---

## `logger_service.dart`

Manages structured log persistence with pluggable sinks and optional file rotation.

### Concepts
| Concept | Details |
| --- | --- |
| `LoggerService.init` | Accepts a custom `LogSink` or creates a rotating `FileLogSink`. You can control file name, directory, max file size, and backup count. |
| `LogSink` | Interface with `write`, `clear`, and `location`. Implement this to forward logs to remote services or in-memory buffers. |
| `FileLogSink` | Default implementation writing JSON lines with optional rotation. |

### Common entry points
- `LoggerService.logUi(...)`: record UI interactions.
- `LoggerService.logApi(...)`: capture request/response metadata when paired with `ApiClient`.
- `LoggerService.readLogs()`: convenience for local debugging (only works with `FileLogSink`).

### Production tips
- Inject a custom `LogSink` (e.g., Sentry, Datadog) by passing `sink:` to `LoggerService.init`.
- Adjust `maxFileBytes` and `maxBackupFiles` to meet retention requirements.
- Use `LoggerService.resetForTest()` in unit tests to isolate state.
