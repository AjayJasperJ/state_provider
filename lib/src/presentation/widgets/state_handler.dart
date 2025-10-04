import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/app_error.dart';
import '../../domain/entities/load_state.dart';
import '../../utils/dev_logger.dart';

class StateHandler<T extends ChangeNotifier, D> extends StatefulWidget {
  const StateHandler({
    super.key,
    required this.state,
    this.idleBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.successBuilder,
    this.failureBuilder,
    this.onInit,
  });

  final LoadState<D> Function(BuildContext, T) state;
  final Widget Function(BuildContext, T)? idleBuilder;
  final Widget Function(BuildContext, T)? emptyBuilder;
  final Widget Function(BuildContext, T)? loadingBuilder;
  final Widget Function(BuildContext, T, D)? successBuilder;
  final Widget Function(
    BuildContext,
    T,
    AppError,
    D?,
    Future<void> Function()?,
  )?
  failureBuilder;
  final Future<void> Function(T)? onInit;

  @override
  State<StateHandler<T, D>> createState() => _StateHandlerState<T, D>();
}

class _StateHandlerState<T extends ChangeNotifier, D>
    extends State<StateHandler<T, D>> {
  @override
  void initState() {
    super.initState();
    if (widget.onInit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = context.read<T>();
        Future.microtask(() async {
          try {
            await widget.onInit!(provider);
          } catch (error, stackTrace) {
            DevLogger.error(
              'StateHandler.onInit error',
              tag: 'STATE_HANDLER',
              error: error,
              stackTrace: stackTrace,
            );
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<T, LoadState<D>>(
      selector: (_, provider) => widget.state(context, provider),
      builder: (context, state, _) {
        final provider = context.read<T>();
        Widget child;

        if (state.isLoading) {
          child = KeyedSubtree(
            key: const ValueKey('loading'),
            child:
                widget.loadingBuilder?.call(context, provider) ??
                const Center(child: Text('Loading state')),
          );
        } else if (state.hasError) {
          final error = state.error!;
          final Future<void> Function()? onRetry =
              (state.data == null && widget.onInit != null)
              ? () async {
                  try {
                    final p = context.read<T>();
                    await widget.onInit!(p);
                  } catch (error, stackTrace) {
                    DevLogger.error(
                      'StateHandler retry error',
                      tag: 'STATE_HANDLER',
                      error: error,
                      stackTrace: stackTrace,
                    );
                  }
                }
              : null;

          child = KeyedSubtree(
            key: const ValueKey('failure'),
            child:
                widget.failureBuilder?.call(
                  context,
                  provider,
                  error,
                  state.data,
                  onRetry,
                ) ??
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failure state'),
                      if (onRetry != null) const SizedBox(height: 8),
                      if (onRetry != null)
                        ElevatedButton(
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                ),
          );
        } else if (state.data is Iterable && (state.data as Iterable).isEmpty) {
          child = KeyedSubtree(
            key: const ValueKey('empty'),
            child:
                widget.emptyBuilder?.call(context, provider) ??
                const Center(child: Text('Empty state')),
          );
        } else {
          if (state.data == null) {
            child = KeyedSubtree(
              key: const ValueKey('idle'),
              child:
                  widget.idleBuilder?.call(context, provider) ??
                  const Center(child: Text('Null state')),
            );
          } else {
            child = KeyedSubtree(
              key: const ValueKey('success'),
              child:
                  widget.successBuilder?.call(
                    context,
                    provider,
                    state.data as D,
                  ) ??
                  const Center(child: Text('Success state')),
            );
          }
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: KeyedSubtree(
            key: switch (true) {
              true when state.isLoading => const ValueKey('loading'),
              true when state.hasError => const ValueKey('failure'),
              true
                  when state.data is Iterable &&
                      (state.data as Iterable).isEmpty =>
                const ValueKey('empty'),
              true when state.data == null => const ValueKey('idle'),
              _ => const ValueKey('success'),
            },
            child: child,
          ),
        );
      },
    );
  }
}
