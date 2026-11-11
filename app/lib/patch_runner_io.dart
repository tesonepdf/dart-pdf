import 'dart:io';
import 'dart:math' as math;

import 'dpat_apply.dart';
import 'patch_manifest.dart';

/// Scarica [url] in [path]. [onBytes] riceve i byte arrivati (negativi se un
/// tentativo riparte da capo). Lancia [PatchCancelledException] se annullato.
typedef PatchDownloader = Future<void> Function(
  String url,
  String path, {
  int? expectedSize,
  required void Function(int bytes) onBytes,
});

Future<void> _emptyDirectory(Directory dir) async {
  if (!await dir.exists()) {
    await dir.create(recursive: true);
    return;
  }
  await for (final e in dir.list()) {
    try {
      await e.delete(recursive: true);
    } catch (_) {}
  }
}

/// Prepara in [workDir] l'APK della build corrente usando le patch.
///
/// Legge `patches.json` dagli [assets] della release, sceglie la strada piu'
/// leggera ([planUpdate]), scarica solo i pezzi che servono, ricostruisce l'APK
/// e ne controlla l'SHA-256. Restituisce il percorso del file pronto da
/// installare, oppure null se non c'e' una strada o qualcosa non torna: allora
/// chi chiama scarica l'APK completo. [forceFull] parte sempre dall'APK base
/// (reinstallazione completa). Lancia [PatchCancelledException] se annullato.
Future<String?> runPatchPlan({
  required Map<String, String> assets,
  required int installedBuild,
  required String? installedApkPath,
  required Directory workDir,
  required PatchDownloader download,
  bool forceFull = false,
  void Function(double? fraction)? onProgress,
  bool Function()? isCancelled,
  void Function(String message)? log,
}) async {
  final manifestUrl = assets[kPatchManifestName];
  if (manifestUrl == null) return null;
  try {
    await _emptyDirectory(workDir);
    final manifestPath = '${workDir.path}/$kPatchManifestName';
    await download(manifestUrl, manifestPath, onBytes: (_) {});
    final manifest =
        PatchManifest.tryParse(await File(manifestPath).readAsString());
    if (manifest == null) {
      log?.call('elenco delle patch non leggibile');
      return null;
    }

    final first = planUpdate(manifest, installedBuild,
        forceFull: forceFull || installedApkPath == null);
    if (first == null) {
      log?.call('nessuna strada con le patch dalla build $installedBuild');
      return null;
    }
    var plan = first;
    if (!plan.useBase) {
      // L'APK installato deve essere proprio quello da cui parte la patch.
      final sha = await sha256OfFile(installedApkPath!);
      if (sha != plan.edges.first.fromSha) {
        log?.call("l'APK installato non e' quello della build pubblicata");
        final fallback =
            planUpdate(manifest, installedBuild, forceFull: true);
        if (fallback == null) return null;
        plan = fallback;
      }
    }

    final names = [
      if (plan.useBase) plan.base.asset,
      for (final e in plan.edges) e.asset,
    ];
    for (final n in names) {
      if (!assets.containsKey(n)) {
        log?.call('manca nella release: $n');
        return null;
      }
    }

    var received = 0;
    final total = plan.downloadBytes;
    void bump(int delta) {
      received += delta;
      onProgress?.call(total > 0
          ? math.max(0.0, math.min(1.0, received / total))
          : null);
    }

    final finalPath = '${workDir.path}/DartPDF-Android.apk';
    String current;
    var currentIsTemp = false;
    if (plan.useBase) {
      final basePath = '${workDir.path}/base.apk';
      await download(assets[plan.base.asset]!, basePath,
          expectedSize: plan.base.size, onBytes: bump);
      if (await sha256OfFile(basePath) != plan.base.sha256) {
        log?.call("l'APK base scaricato non coincide");
        await _emptyDirectory(workDir);
        return null;
      }
      current = basePath;
      currentIsTemp = true;
    } else {
      current = installedApkPath!;
    }

    for (var i = 0; i < plan.edges.length; i++) {
      if (isCancelled?.call() ?? false) throw const PatchCancelledException();
      final edge = plan.edges[i];
      final patchPath = '${workDir.path}/patch-${edge.from}-${edge.to}.dpat';
      await download(assets[edge.asset]!, patchPath,
          expectedSize: edge.size, onBytes: bump);
      onProgress?.call(null);
      final out = i == plan.edges.length - 1
          ? finalPath
          : '${workDir.path}/step-$i.apk';
      await applyDpatFile(
        oldPath: current,
        patchPath: patchPath,
        outPath: out,
        isCancelled: isCancelled,
      );
      await File(patchPath).delete();
      if (currentIsTemp) await File(current).delete();
      current = out;
      currentIsTemp = true;
    }
    if (plan.edges.isEmpty) {
      await File(current).rename(finalPath);
    }

    if (await sha256OfFile(finalPath) != plan.target.sha256) {
      log?.call("l'APK ricostruito non coincide con quello pubblicato");
      await _emptyDirectory(workDir);
      return null;
    }
    return finalPath;
  } on PatchCancelledException {
    await _emptyDirectory(workDir);
    rethrow;
  } catch (e) {
    log?.call('patch non riuscita: $e');
    try {
      await _emptyDirectory(workDir);
    } catch (_) {}
    return null;
  }
}
