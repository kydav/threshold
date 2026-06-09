import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'delivery_service.dart';

/// Watches network connectivity and retries pending deliveries whenever
/// the device transitions from offline → online.
class ConnectivityWatcher {
  ConnectivityWatcher(this._delivery);
  final DeliveryService _delivery;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOffline = false;

  void start() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);

      if (_wasOffline && isOnline) {
        // Came back online — retry any pending deliveries.
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          _delivery.retryPending(uid);
        }
      }

      _wasOffline = !isOnline;
    });
  }

  void dispose() => _sub?.cancel();
}

final connectivityWatcherProvider = Provider<ConnectivityWatcher>((ref) {
  final watcher = ConnectivityWatcher(ref.read(deliveryServiceProvider));
  watcher.start();
  ref.onDispose(watcher.dispose);
  return watcher;
});
