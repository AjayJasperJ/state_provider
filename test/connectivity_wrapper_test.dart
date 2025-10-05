import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:state_provider/state_provider.dart';

class _TestInternetService extends ChangeNotifier implements InternetService {
  _TestInternetService(this._isConnected);

  bool _isConnected;
  bool _showOfflineBanner = false;

  void setConnection(bool connected) {
    if (_isConnected == connected) return;
    _isConnected = connected;
    notifyListeners();
  }

  @override
  bool get isConnected => _isConnected;

  @override
  bool get showOfflineBanner => _showOfflineBanner;

  @override
  void hideBanner() {
    _showOfflineBanner = false;
    notifyListeners();
  }
}

class _DummyNotifier extends ChangeNotifier {
  int reconnectCount = 0;

  void markReconnect() {
    reconnectCount++;
  }
}

void main() {
  group('ConnectivityWrapperProvider', () {
    testWidgets('invokes callback with provider when connection is restored', (
      tester,
    ) async {
      final internet = _TestInternetService(false);
      final notifier = _DummyNotifier();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<InternetService>.value(value: internet),
            ChangeNotifierProvider<_DummyNotifier>.value(value: notifier),
          ],
          child: MaterialApp(
            home: ConnectivityWrapperProvider<_DummyNotifier>(
              onReconnect: (provider) => provider.markReconnect(),
              child: const Scaffold(body: SizedBox.shrink()),
            ),
          ),
        ),
      );

      expect(notifier.reconnectCount, 0);

      internet.setConnection(true);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(notifier.reconnectCount, 1);
    });
  });
}
