import 'dart:async';

import 'package:flutter/widgets.dart';

import 'pagination_notifier.dart';

/// Coordinates scroll events with a [PaginationNotifier] so that load-more
/// requests fire automatically when the user nears the bottom of the list.
class PaginationController<D, E> {
  PaginationController({
    required this.notifier,
    double loadMoreThreshold = 200,
    ScrollController? scrollController,
    bool disposeController = true,
  }) : _threshold = loadMoreThreshold,
       _controller = scrollController ?? ScrollController(),
       _ownsController = scrollController == null,
       _disposeController = disposeController {
    _controller.addListener(_handleScroll);
  }

  final PaginationNotifier<D, E> notifier;
  final double _threshold;
  final ScrollController _controller;
  final bool _ownsController;
  final bool _disposeController;

  /// Provides the [ScrollController] used for automatic pagination.
  ScrollController get controller => _controller;

  void _handleScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.extentAfter > _threshold) return;
    final state = notifier.state;
    if (state.loadMoreError != null) return;
    if (!notifier.hasMore) return;
    if (notifier.isFetching) return;

    unawaited(notifier.loadMore());
  }

  /// Stops listening to scroll events. If the controller was created internally
  /// it will also be disposed depending on [disposeController].
  void dispose() {
    _controller.removeListener(_handleScroll);
    if (_ownsController && _disposeController) {
      _controller.dispose();
    }
  }
}
