import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/datasources/internet_service.dart';
import '../../utils/dev_logger.dart';

/// A small wrapper that calls [onReconnect] when the app transitions from
/// offline to online. Uses the app-wide [InternetService] provider so
/// listeners are consistent across the widget tree.
///
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReconnect;
  final bool onlyWhenVisible;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.onReconnect,
    this.onlyWhenVisible = true,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  InternetService? _internetService;
  bool? _lastState;
  Timer? _debounce;

  static Timer? _globalDebounce;
  static bool? _lastGlobalState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final old = _internetService;
    final current = Provider.of<InternetService?>(context);
    if (old != current) {
      old?.removeListener(_onStatusChange);
      _internetService = current;
      _internetService?.addListener(_onStatusChange);
      _lastState = _internetService?.isConnected;
    }
  }

  void _onStatusChange() {
    final current = _internetService?.isConnected ?? false;
    final last = _lastState ?? current;
    if (last == current) return;
    _lastState = current;

    // Global toast logic
    if (_lastGlobalState != current) {
      _lastGlobalState = current;
      _globalDebounce?.cancel();
      _globalDebounce = Timer(const Duration(milliseconds: 300), () {
        if (!current) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Internet Disconnected'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Internet Connected'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
    if (current) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        if (widget.onlyWhenVisible) {
          try {
            final route = ModalRoute.of(context);
            if (route?.isCurrent ?? false) widget.onReconnect?.call();
          } catch (e) {
            DevLogger.error(
              'Error in onReconnect',
              tag: 'CONNECTIVITY_WRAPPER',
              error: e,
            );
          }
        } else {
          widget.onReconnect?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _internetService?.removeListener(_onStatusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

typedef ConnectivityProviderCallback<T> = FutureOr<void> Function(T provider);

/// Convenience wrapper that reads a Provider of type [T] before executing the
/// reconnect callback. Use this when your refresh logic depends on a
/// ChangeNotifier or other provider instance.
class ConnectivityWrapperProvider<T> extends StatelessWidget {
  const ConnectivityWrapperProvider({
    super.key,
    required this.child,
    required this.onReconnect,
    this.onlyWhenVisible = true,
  });

  final Widget child;
  final ConnectivityProviderCallback<T> onReconnect;
  final bool onlyWhenVisible;

  @override
  Widget build(BuildContext context) {
    return ConnectivityWrapper(
      onlyWhenVisible: onlyWhenVisible,
      onReconnect: () {
        late T provider;
        try {
          provider = context.read<T>();
        } catch (error, stackTrace) {
          DevLogger.error(
            'ConnectivityWrapperProvider could not read provider of type $T',
            tag: 'CONNECTIVITY_WRAPPER_PROVIDER',
            error: error,
            stackTrace: stackTrace,
          );
          return;
        }

        final result = onReconnect(provider);
        if (result is Future) {
          unawaited(result);
        }
      },
      child: child,
    );
  }
}
