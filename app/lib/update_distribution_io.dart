import 'dart:io';
import 'dart:ffi';

import 'package:flutter/services.dart';

/// Flatpak and Snap set these variables for sandboxed processes. Those
/// installations update through their package manager, so the app must not
/// advertise a parallel AppImage download from GitHub.
bool get defaultStoreManagedUpdateChannel =>
    const bool.fromEnvironment('PDF_STORE_MANAGED') ||
    (Platform.isWindows &&
        File('${File(Platform.resolvedExecutable).parent.path}/AppxManifest.xml')
            .existsSync()) ||
    (Platform.isMacOS &&
        File(
          '${File(Platform.resolvedExecutable).parent.parent.path}/_MASReceipt/receipt',
        ).existsSync()) ||
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

/// ABI of the running process; no shell probe or dependency required.
String get defaultUpdateArchitecture => switch (Abi.current()) {
      Abi.macosArm64 || Abi.windowsArm64 || Abi.linuxArm64 => 'arm64',
      Abi.macosX64 || Abi.windowsX64 || Abi.linuxX64 => 'x64',
      _ => 'unknown',
    };
