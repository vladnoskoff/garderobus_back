import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportService {
  static const _supportEmail = 'garderobus@list.ru';

  static Future<void> composeEmail({
    required String subject,
    required String body,
  }) async {
    final mailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    if (!await launchUrl(mailUri)) {
      throw Exception('Unable to launch mail client');
    }
  }

  static Future<SupportDeviceInfo> loadDeviceInfo() async {
    final plugin = DeviceInfoPlugin();

    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return SupportDeviceInfo(
        model: info.utsname.machine ?? info.model ?? 'Unknown iOS device',
        osVersion: 'iOS ${info.systemVersion ?? ''}'.trim(),
      );
    }

    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      final brand = info.brand ?? '';
      final model = info.model ?? '';
      return SupportDeviceInfo(
        model: [brand, model].where((part) => part.trim().isNotEmpty).join(' ').trim(),
        osVersion: 'Android ${info.version.release ?? ''}'.trim(),
      );
    }

    return const SupportDeviceInfo(
      model: 'Unknown device',
      osVersion: 'Unknown OS version',
    );
  }
}

class SupportDeviceInfo {
  final String model;
  final String osVersion;

  const SupportDeviceInfo({
    required this.model,
    required this.osVersion,
  });
}
