# Domain Layer

**Files covered:**

- `lib/src/domain/entities/app_error.dart`
- `lib/src/domain/entities/app_result.dart`
- `lib/src/domain/entities/load_state.dart`
- `lib/src/domain/entities/pagination_state.dart`
- `lib/src/domain/value_objects/error_messages.dart`
- `lib/src/domain/value_objects/pagination_page.dart`

## Error and result modeling

### `app_error.dart`
Defines the `AppError` class and `AppErrorType` enum. Each factory constructor produces a descriptive, user-friendly message along with optional status codes and exceptions.

**Use it when:** you need a typed representation of failures that can be displayed to users or logged.

### `app_result.dart`
Provides a sealed-style result wrapper with `AppSuccess`/`AppFailure`, `when`, and `map` helpers.

**Use it when:** returning from repository or service calls where you want to unify success and failure handling without throwing exceptions.

### `error_messages.dart`
Maps HTTP status codes to friendly strings through `mapErrorMessage`. Supply custom fallbacks to override defaults.

**Use it when:** you want consistent error messaging across screens and services.

---

## Request lifecycle state

### `load_state.dart`
A lightweight tri-state model (`idle`, `loading`, `success`, `failure`) used by `StateHandler`.

- Factories: `LoadState.idle`, `.loading`, `.success`, `.failure`.
- `copyWith` supports clearing errors and updating payloads.

**Use it when:** representing the state of single-shot fetches like profile loads or detail requests.

---

## Pagination primitives

### `pagination_state.dart`
Immutable snapshot of paginated data containing items, loading flags, and error channels.

Key fields:
- `items`: list of fetched records.
- `isInitialLoading` / `isLoadingMore`: track fetch progress.
- `initialError` / `loadMoreError`: differentiate error types.
- `hasMore`: indicates whether more pages are available.

### `pagination_page.dart`
Value object used by `PaginationNotifier` to describe a single page and metadata (e.g., `pageNumber`, `hasMore`, `totalItems`).

**Use them when:** building reversible pagination flows where UI must respond to both initial load and incremental fetches.
