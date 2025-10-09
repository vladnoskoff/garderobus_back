import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricMethod {
  face,
  fingerprint,
  other,
}

class BiometricAuthSupport {
  final bool canAuthenticate;
  final BiometricMethod? preferredMethod;

  const BiometricAuthSupport({
    required this.canAuthenticate,
    this.preferredMethod,
  });
}

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<BiometricAuthSupport> checkSupport() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      if (!isSupported) {
        return const BiometricAuthSupport(canAuthenticate: false);
      }

      final bool canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        return const BiometricAuthSupport(canAuthenticate: false);
      }

      final List<BiometricType> available = await _auth.getAvailableBiometrics();
      BiometricMethod? method;

      if (available.contains(BiometricType.face)) {
        method = BiometricMethod.face;
      } else if (available.contains(BiometricType.fingerprint)) {
        method = BiometricMethod.fingerprint;
      } else if (available.isNotEmpty) {
        method = BiometricMethod.other;
      }

      return BiometricAuthSupport(
        canAuthenticate: method != null,
        preferredMethod: method,
      );
    } on PlatformException {
      return const BiometricAuthSupport(canAuthenticate: false);
    }
  }

  static Future<bool> authenticate({
    String reason = 'Подтвердите личность для доступа к гардеробу',
  }) async {
    try {
      final support = await checkSupport();
      if (!support.canAuthenticate) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
