import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/pagination_state.dart';
import '../../utils/dev_logger.dart';

class PaginationStateHandler<T extends ChangeNotifier, D, E>
    extends StatefulWidget {
  const PaginationStateHandler({
    super.key,
    required this.state,
    required this.onLoadMore,
    required this.successBuilder,
    this.initialLoadingBuilder,
    this.emptyBuilder,
    this.failureBuilder,
    this.onInit,
    this.errorMessageBuilder,
  });

  final PaginationState<D, E> Function(BuildContext, T) state;
  final Future<void> Function(T) onLoadMore;
  final Future<void> Function(T)? onInit;
  final Widget Function(
    BuildContext,
    T,
    ScrollController,
    PaginationState<D, E>,
    Future<void> Function(),
  )
  successBuilder;
  final Widget Function(BuildContext, T)? initialLoadingBuilder;
  final Widget Function(BuildContext, T)? emptyBuilder;
  final Widget Function(BuildContext, T, E, Future<void> Function())?
  failureBuilder;
  final String Function(E error)? errorMessageBuilder;

  @override
  State<PaginationStateHandler<T, D, E>> createState() =>
      _PaginationStateHandlerState<T, D, E>();
}

class _PaginationStateHandlerState<T extends ChangeNotifier, D, E>
    extends State<PaginationStateHandler<T, D, E>> {
  final ScrollController _scrollController = ScrollController();
  bool _loadMorePending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.onInit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final provider = context.read<T>();
        try {
          await widget.onInit!(provider);
        } catch (error, stackTrace) {
          DevLogger.error(
            'PaginationStateHandler onInit error',
            tag: 'PAGINATION_STATE_HANDLER',
            error: error,
            stackTrace: stackTrace,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final provider = context.read<T>();
    final state = widget.state(context, provider);

    if (!state.hasMore) return;
    if (state.isInitialLoading) return;
    if (state.isLoadingMore) return;
    if (state.loadMoreError != null) return;
    if (_loadMorePending) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final delta = maxScroll - currentScroll;

    if (delta < 500) {
      _loadMore(provider);
    }
  }

  Future<void> _loadMore(T provider) async {
    if (_loadMorePending) return;
    _loadMorePending = true;
    try {
      await widget.onLoadMore(provider);
    } finally {
      _loadMorePending = false;
    }
  }

  Widget _buildInitialLoading(BuildContext context, T provider) {
    return widget.initialLoadingBuilder?.call(context, provider) ??
        const Center(child: CircularProgressIndicator());
  }

  Widget _buildInitialFailure(BuildContext context, T provider, E error) {
    retry() => _loadMore(provider);
    final builder = widget.failureBuilder;
    if (builder != null) {
      return builder(context, provider, error, retry);
    }

    final message = widget.errorMessageBuilder?.call(error) ?? error.toString();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Error: $message'),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, T provider) {
    return widget.emptyBuilder?.call(context, provider) ??
        const Center(child: Text('No items found'));
  }

  Widget _buildSuccess(
    BuildContext context,
    T provider,
    PaginationState<D, E> state,
  ) {
    return widget.successBuilder(
      context,
      provider,
      _scrollController,
      state,
      () => _loadMore(provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<T, PaginationState<D, E>>(
      selector: (_, provider) => widget.state(context, provider),
      builder: (context, state, _) {
        final provider = context.read<T>();

        if (state.isEmpty) {
          if (state.isInitialLoading) {
            return _buildInitialLoading(context, provider);
          }

          if (state.initialError != null) {
            return _buildInitialFailure(
              context,
              provider,
              state.initialError as E,
            );
          }

          return _buildEmpty(context, provider);
        }

        return _buildSuccess(context, provider, state);
      },
    );
  }
}
