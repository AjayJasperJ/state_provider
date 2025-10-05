# Presentation Layer

**Files covered:**

- `lib/src/presentation/controllers/pagination_controller.dart`
- `lib/src/presentation/controllers/pagination_notifier.dart`
- `lib/src/presentation/widgets/connectivity_wrapper.dart`
- `lib/src/presentation/widgets/pagination_list_view.dart`
- `lib/src/presentation/widgets/pagination_state_handler.dart`
- `lib/src/presentation/widgets/state_handler.dart`

## Controllers

### `pagination_notifier.dart`
`PaginationNotifier<D, E>` orchestrates initial and incremental fetches. Configure it with:
- `fetchPage`: async callback returning `PaginationFetchResult<D, E>`.
- `keySelector`: prevents duplicate entries.
- `errorTransformer` / `onFetchError`: customize error handling.

**Use it when:** you need a reusable `ChangeNotifier` providing `PaginationState` to widgets.

Typical flow:
```dart
final notifier = PaginationNotifier<Item, AppError>(
  fetchPage: (page) => repository.fetchItems(page),
  keySelector: (item) => item.id,
);
await notifier.loadInitial();
```

### `pagination_controller.dart`
A scroll-aware helper that triggers `loadMore` when the user nears the bottom of a list. Provide a `PaginationNotifier` and optional `ScrollController`.

**Use it when:** building infinite scroll lists where you want automatic pagination.

## Widgets

### `state_handler.dart`
Builder-driven widget for single-shot requests modeled with `LoadState<T>`.
- `onInit`: optional lazy loader invoked after first build.
- `loadingBuilder`, `failureBuilder`, `emptyBuilder`, `idleBuilder`, `successBuilder`: customize UI by state.

**Use it when:** wrapping provider-driven screens that fetch data once (e.g., profile, settings).

### `pagination_state_handler.dart`
Combines a provider instance, `PaginationState`, and UI builders to manage full pagination flows—including loading, empty, error, and success states.

**Use it when:** wiring `PaginationNotifier` into the widget tree along with `PaginationListView`.

### `pagination_list_view.dart`
Helper ListView that renders items plus inline loading/error footers.
- Props: `items`, `isLoadingMore`, `loadMoreError`, `onRetryLoadMore`.
- Works seamlessly with `PaginationController` and `PaginationStateHandler`.

**Use it when:** you want a ready-made list scaffold but prefer custom item builders.

### `connectivity_wrapper.dart`
Listens to `InternetService` and reacts to connectivity changes.
- `ConnectivityWrapper`: base widget that exposes an `onReconnect` callback without automatically reading providers.
- `ConnectivityWrapperProvider<T>`: convenience wrapper that injects a provider of type `T` into the reconnect callback, saving you from calling `context.read<T>()` manually.
- Both variants show snackbars when the device goes offline/online using shared debounced notifications.

**Use them when:** wrapping screens that should respond to network changes, especially ones with pagination or long-running requests. Use the provider variant for automatic retries that depend on a notifier instance.

## Composition tips

1. Provide your notifier/controller using `ChangeNotifierProvider` or `Provider`.
2. Combine `PaginationStateHandler` + `PaginationListView` for paginated screens.
3. Wrap top-level routes with `ConnectivityWrapper` to display global network feedback.
4. Use `StateHandler` for simpler "fetch once" flows.
