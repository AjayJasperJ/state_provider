<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

## State Provider

`state_provider` provides a reusable pagination and async-state toolkit for Flutter apps built on `ChangeNotifier`/`Provider`. It includes:

- `AppError` / `AppErrorType` – typed error envelopes with convenience factories for network, serialization, auth, and unknown failures, plus `mapErrorMessage` for HTTP status -> friendly message mapping.
- `AppResult<T>` – a sealed result type with `AppSuccess` / `AppFailure` helpers and `when`/`map` utilities.
- `LoadState<T>` – a minimal tri-state holder for request lifecycles (`idle`, `loading`, `success`, `failure`) used by the generic `StateHandler` widget.
- `StateHandler<T, D>` – a builder-driven widget that renders the right UI branch for a `LoadState`, complete with optional retry wiring.
- `PaginationState<D, E>` – immutable pagination snapshot describing items, loading flags, and any initial/load-more errors.
- `PaginationStateHandler<T, D, E>` – a widget that listens to your provider, wires up infinite scroll, calls your pagination callbacks, and exposes builders for loading/empty/error/success.
- `PaginationListView<D, E>` – an opt-in helper that renders a `ListView` with inline loading and error footers while leaving item rendering to your builder.
- `DevLogger` – a colored console logger with debug-mode support, perfect for development and debugging.

The goal is to keep networking and pagination UIs declarative—providers expose typed state, widgets react through builders, and no widget-level `setState` calls are required.

## Getting started

Add the package as a path dependency inside a Flutter app:

```yaml
dependencies:
  state_provider:
    path: packages/state_provider
```

Then import it where you build your widgets:

```dart
import 'package:state_provider/state_provider.dart';
```

## Usage

Expose `PaginationState` from a provider:

```dart
class ProductsProvider extends ChangeNotifier {
  ProductsProvider(this._repository)
      : _state = const PaginationState<Product, AppError>();

  final ProductsRepository _repository;
  PaginationState<Product, AppError> _state;

  PaginationState<Product, AppError> get state => _state;

  Future<void> loadInitial() async {
    // Update `_state` and call notifyListeners();
  }

  Future<void> loadMore() async {
    // Append new items and notify.
  }
}
```

Compose the pagination handler in your widget tree:

```dart
PaginationStateHandler<ProductsProvider, Product, AppError>(
  state: (context, provider) => provider.state,
  onInit: (provider) => provider.loadInitial(),
  onLoadMore: (provider) => provider.loadMore(),
  errorMessageBuilder: (error) => error.message,
  successBuilder: (context, provider, controller, state, loadMore) {
    return PaginationListView<Product, AppError>(
      controller: controller,
      items: state.items,
      isLoadingMore: state.isLoadingMore,
      loadMoreError: state.loadMoreError,
      onRetryLoadMore: loadMore,
      itemBuilder: (context, index, product) => ProductTile(product),
    );
  },
  initialLoadingBuilder: (context, provider) => const Center(
    child: CircularProgressIndicator(),
  ),
  failureBuilder: (context, provider, error, retry) => ErrorView(error, retry),
  emptyBuilder: (context, provider) => const EmptyState(),
);

For simpler “single-shot” requests, use the generic `StateHandler` with `LoadState`:

```dart
class ProfileProvider extends ChangeNotifier {
  LoadState<User> state = const LoadState();

  Future<void> load() async {
    state = const LoadState(isLoading: true);
    notifyListeners();

    final result = await api.fetchProfile();
    state = result.when(
      success: (user) => LoadState.success(user),
      failure: (error) => LoadState.failure(error),
    );
    notifyListeners();
  }
}

StateHandler<ProfileProvider, User>(
  state: (context, provider) => provider.state,
  onInit: (provider) => provider.load(),
  loadingBuilder: (context, _) => const CircularProgressIndicator.adaptive(),
  failureBuilder: (context, _, error, __, retry) => ErrorView(error, retry),
  successBuilder: (context, _, user) => ProfileView(user: user),
);
```
```

## Features A-Z

### 🅰️ **ApiClient**
Complete HTTP client with typed responses, error handling, authentication support, and logging integration.
- **GET/POST/Multipart** - Full HTTP method support with JSON and form data
- **Authentication Headers** - Configurable auth header injection
- **Error Mapping** - Automatic HTTP status code to `AppError` conversion
- **Request Logging** - Integrated request/response logging with `LoggerService`

### 🅰️ **ApiResponse<T>**
Wrapper for HTTP responses containing data, status code, and raw response access for advanced use cases.

### 🅰️ **AppError & AppErrorType**
Comprehensive error handling system with typed error categories and user-friendly messages.
- **11 Error Types**: `network`, `timeout`, `unauthorized`, `forbidden`, `notFound`, `validation`, `server`, `serialization`, `cancelled`, `unknown`, `unauthenticated`
- **Factory Methods** - Convenient constructors for common error scenarios
- **Status Code Mapping** - HTTP status codes automatically mapped to appropriate error types

### 🅰️ **AppResult<T>**
Sealed class result type for safe error handling with functional programming patterns.
- **Success/Failure** - Clear success (`AppSuccess`) and failure (`AppFailure`) states
- **Pattern Matching** - `when()` method for exhaustive handling
- **Transformations** - `map()` method for data transformation chains
- **Type Safety** - Compile-time guarantees for error handling

### 🅱️ **Bootstrap (StateProviderBootstrap)**
One-line initialization utility for setting up all core services and dependencies.
- **Host Configuration** - Automatic API base host and path setup
- **Service Registration** - Initializes logging, caching, and connectivity services
- **Client Factory** - Creates configured `CachedApiClient` instances

### 🅲️ **CachedApiClient**
Network client with automatic offline request queueing and intelligent retry mechanisms.
- **Offline Queueing** - Requests are cached when offline and replayed when online
- **Retry Policies** - Configurable backoff strategies and retry limits
- **Transparent Caching** - Drop-in replacement for `ApiClient` with caching benefits

### 🅲️ **CachedRequest**
Persistent request representation that survives app restarts and supports retry logic.
- **Serializable** - JSON serialization for disk persistence
- **Retry Tracking** - Attempt counting and next retry timestamps
- **Method Support** - GET, POST, multipart requests with full parameter preservation

### 🅲️ **ConnectivityWrapper**
Widget that responds to network state changes with automatic callbacks and user notifications.
- **Reconnection Callbacks** - Execute code when connectivity is restored
- **Global Notifications** - Automatic snackbar notifications for connection state
- **Smart Debouncing** - Prevents notification spam during connection fluctuations

### �️ **DevLogger**
Colored console logger with debug-mode support, perfect for development and debugging.
- **Colored Output** - Green success, yellow/red errors, blue info messages
- **Debug-Only** - Automatically disabled in release builds for zero performance impact
- **Structured Logging** - JSON-like data logging with timestamps
- **Specialized Methods** - `success()`, `error()`, `info()`, `api()`, `pagination()`, `connectivity()`, `cache()`
- **Multi-Channel** - Both `developer.log()` and `debugPrint()` for maximum visibility
- **Stack Traces** - Complete error context with stack trace logging

```dart
DevLogger.success('API call completed successfully');
DevLogger.error('Network request failed', error: exception);
DevLogger.api(method: 'GET', endpoint: '/users', statusCode: 200);
DevLogger.pagination('Loading page 2', data: {'items': 20});
```

### �🅴️ **Error Message Mapping**
HTTP status code to user-friendly message conversion with customizable fallback text.
- **Comprehensive Coverage** - Messages for all common HTTP status codes (400-504)
- **Customizable** - Override messages with custom fallback text
- **User-Friendly** - Clear, actionable error messages for end users

### 🅷️ **HostServer**
Singleton configuration service for API endpoint management with validation.
- **Global Configuration** - Centralized API host and base path management
- **Initialization Validation** - Runtime checks ensure proper setup before use
- **Environment Support** - Easy switching between development/staging/production endpoints

### 🅸️ **InternetService**
Real-time connectivity monitoring with notification support and singleton pattern.
- **Real-time Monitoring** - Continuous connectivity state tracking
- **ChangeNotifier** - Reactive updates throughout the app via Provider
- **Offline Banners** - Built-in UI feedback for connection state changes

### 🅻️ **LoadState<T>**
Simple state container for single-request lifecycles with built-in state management.
- **Tri-State Model** - Idle, loading, success, error states
- **Factory Constructors** - Convenient state creation methods
- **Immutable Updates** - `copyWith()` method for safe state transitions
- **Null Safety** - Proper handling of optional data and errors

### 🅻️ **LoggerService**
Structured JSON logging with categorized events and persistent file storage.
- **Structured Logging** - JSON format with timestamps and categories
- **Event Categories** - UI events, API calls, and custom event types
- **File Persistence** - Logs survive app restarts and crashes
- **Async Operations** - Non-blocking logging operations

### 🅿️ **PaginationListView<D, E>**
Ready-to-use ListView with built-in loading states and error handling for paginated content.
- **Loading Indicators** - Automatic loading spinners for load-more operations
- **Error Footers** - Built-in error display with retry buttons
- **Customizable Builders** - Override default loading and error UI
- **Scroll Integration** - Works seamlessly with `PaginationStateHandler`

### 🅿️ **PaginationState<D, E>**
Immutable state container for paginated data with comprehensive loading and error states.
- **Item Management** - Type-safe list of paginated items
- **Dual Loading States** - Separate initial and load-more loading indicators
- **Error Handling** - Independent error states for initial load and pagination
- **Pagination Control** - `hasMore` flag for infinite scroll control
- **Immutable Updates** - `copyWith()` with selective error clearing

### 🅿️ **PaginationStateHandler<T, D, E>**
Complete pagination widget that handles infinite scroll, loading states, and error recovery.
- **Automatic Scroll Detection** - Triggers load-more at customizable threshold (500px)
- **State Management** - Listens to Provider state changes with Selector optimization
- **Builder Pattern** - Separate builders for loading, empty, error, and success states
- **Error Recovery** - Built-in retry mechanisms for failed pagination requests
- **Lifecycle Management** - Automatic initialization and disposal

### �️ **PaginationNotifier<D, E>**
Drop-in `ChangeNotifier` that orchestrates paginated fetching logic and exposes `PaginationState` updates.
- **Declarative Fetching** - Supply a single `fetchPage(page)` callback that returns items and `hasMore`.
- **Duplicate Prevention** - Optional `keySelector` keeps item lists unique across pages.
- **Error Surfacing** - Routes failures into `initialError` / `loadMoreError` for UI display.
- **Convenience APIs** - `loadInitial()`, `loadMore()`, `refresh()`, `replaceItems()`, and `clearErrors()`.
- **Structured Logging** - Emits `DevLogger.pagination` breadcrumbs for visibility in debug builds.

```dart
final notifier = PaginationNotifier<Item, AppError>(
  fetchPage: (page) async {
    final result = await repository.fetchItems(page: page);
    return result.when(
      success: (data) => PaginationFetchResult.success(
        PaginationPage(items: data.items, hasMore: data.hasMore),
      ),
      failure: (error) => PaginationFetchResult.failure(error),
    );
  },
  keySelector: (item) => item.id,
);

await notifier.loadInitial();
```

### 🅿️ **PaginationController<D, E>**
Scroll controller helper that triggers `loadMore()` automatically as the user approaches the end of a list.
- **Threshold Control** - Customize how close to the bottom a user must scroll before auto-loading (default 200px).
- **Controller Ownership** - Bring your own `ScrollController` or let the helper manage one.
- **Safety Guards** - Respects `hasMore` and `isFetching` flags to prevent duplicate network calls.

```dart
final controller = PaginationController(
  notifier: notifier,
  loadMoreThreshold: 160,
);

ListView.builder(
  controller: controller.controller,
  itemCount: notifier.state.items.length,
  itemBuilder: ...,
);
```

### �🆁️ **RequestCacheManager**
Central orchestrator for offline request queuing, persistence, and replay functionality.
- **Singleton Pattern** - Global instance manages all cached requests
- **Disk Persistence** - Requests survive app restarts via `RequestCacheStore`
- **Replay Logic** - Intelligent request replay when connectivity is restored
- **Retry Policies** - Configurable retry attempts and backoff strategies
- **Memory + Disk** - In-memory queue with persistent storage backup

### 🆁️ **RequestCacheStore**
File-based persistence layer for cached requests with JSON serialization.
- **File Storage** - JSON file storage in app support directory
- **CRUD Operations** - Create, read, update, delete cached requests
- **Error Recovery** - Graceful handling of corrupted cache files
- **Custom Directory** - Configurable storage location for testing

### 🆁️ **RetryPolicy**
Configurable retry strategy with exponential backoff and attempt limits.
- **Exponential Backoff** - Configurable backoff factor and maximum delay
- **Attempt Limits** - Maximum retry attempts per request
- **Error Filtering** - Smart retry decisions based on error types
- **Server Error Control** - Optional retry for server errors (5xx)

### 🆂️ **StateHandler<T, D>**
Generic widget for handling single-request states with provider integration and retry support.
- **Provider Integration** - Works with any `ChangeNotifier` via Selector
- **Builder Pattern** - Separate builders for idle, loading, success, failure, empty states
- **Automatic Initialization** - `onInit` callback for load-on-mount behavior
- **Retry Support** - Built-in retry functionality with error recovery
- **Animated Transitions** - Smooth fade transitions between states
- **Keyed Subtrees** - Optimized rebuilds with proper widget keys

### 🆂️ **StateProviderBootstrap**
Utility class providing one-line setup for all package services and configurations.
- **Service Initialization** - Sets up host, logging, caching in single call
- **Client Factory** - Creates properly configured API clients
- **Flexibility** - Optional service enabling (logger, caching, etc.)
- **Production Ready** - Handles all service interdependencies

## Additional information

This package backs the demo app in the repository root. Feel free to adapt it to your own provider or state management setup. Contributions are welcome—open an issue or pull request.
