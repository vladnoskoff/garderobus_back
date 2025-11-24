import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  NetworkService._();

  static final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  static Future<void> initialize() async {
    final statuses = await _connectivity.checkConnectivity();
    _updateStatus(statuses);
    _subscription ??= _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  static Future<bool> isConnected() async {
    final statuses = await _connectivity.checkConnectivity();
    return statuses.any((status) => status != ConnectivityResult.none);
  }

  static void _updateStatus(List<ConnectivityResult> results) {
    final online = results.any((status) => status != ConnectivityResult.none);
    if (isOnline.value != online) {
      isOnline.value = online;
    } else {
      isOnline.value = online;
    }
  }
}
