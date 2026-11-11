import 'patch_manifest.dart';

/// Senza dart:io (web) non ci sono patch: l'app usa il download normale.
Future<PatchRunResult> buildPatchedApk({
  required Map<String, String> assets,
  required int installedBuild,
  bool forceFull = false,
  void Function(double? fraction)? onProgress,
  bool Function()? isCancelled,
}) async =>
    const PatchRunResult.failed(plainApkIsCurrent: true);
