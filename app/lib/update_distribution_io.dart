import 'dart:io';

import 'package:flutter/services.dart';

/// Flatpak and Snap set these variables for sandboxed processes. Those
/// installations update through their package manager, so the app must not
/// advertise a parallel AppImage download from GitHub.
bool get defaultStoreManagedUpdateChannel =>
    (Platform.environment['FLATPAK_ID']?.isNotEmpty ?? false) ||
    (Platform.environment['SNAP']?.isNotEmpty ?? false);

Future<List<String>> defaultAndroidSupportedAbis() async {
  if (!Platform.isAndroid) return const [];
  final abis = await const MethodChannel('dev.milanko.dartpdf/update')
      .invokeListMethod<String>('supportedAbis');
  if (abis == null || abis.isEmpty) {
    throw StateError('Android did not report any supported app architectures');
  }
  return abis;
}
