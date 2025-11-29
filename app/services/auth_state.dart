import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';

enum AuthDestination { loading, login, pin, home }

class AuthState extends ChangeNotifier {
  AuthState({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  AuthDestination _destination = AuthDestination.loading;
  int? _userId;

  AuthDestination get destination => _destination;
  int? get userId => _userId;
  bool get isReady => _destination != AuthDestination.loading;
  bool get isAuthenticated =>
      _destination == AuthDestination.home || _destination == AuthDestination.pin;
  bool get requiresPin => _destination == AuthDestination.pin;

  Future<void> initialize() async {
    if (_destination != AuthDestination.loading) return;
    await _resolveDestination();
  }

  Future<void> refresh() => _resolveDestination();

  Future<void> _resolveDestination() async {
    final token = await _storage.read(key: 'token');
    final userId = await _storage.read(key: 'user_id');
    if (token != null && userId != null) {
      ApiService.rememberAccessToken(token);
      final parsedId = int.tryParse(userId);
      bool requiresPin = false;
      if (parsedId != null) {
        try {
          final user = await ApiService.getUser(parsedId);
          requiresPin = user['has_pin'] == true;
          await ApiService.sendActivityHeartbeat();
        } catch (_) {
          requiresPin = await ApiService.loadCachedHasPin();
        }
      }
      _userId = parsedId;
      _destination = requiresPin ? AuthDestination.pin : AuthDestination.home;
    } else {
      _destination = AuthDestination.login;
    }
    notifyListeners();
  }

  Future<void> completePinFlow() async {
    _destination = AuthDestination.home;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'token');
    _userId = null;
    _destination = AuthDestination.login;
    notifyListeners();
  }
}
