import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  NetworkService._();

  static final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<ConnectivityResult>? _subscription;

  static Future<void> initialize() async {
    final status = await _connectivity.checkConnectivity();
    _updateStatus(status);
    _subscription ??= _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  static Future<bool> isConnected() async {
    final status = await _connectivity.checkConnectivity();
    return status != ConnectivityResult.none;
  }

  static void _updateStatus(ConnectivityResult result) {
    final online = result != ConnectivityResult.none;
    if (isOnline.value != online) {
      isOnline.value = online;
    } else {
      isOnline.value = online;
    }
  }
}
