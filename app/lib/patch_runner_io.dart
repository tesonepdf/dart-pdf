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
/// e ne controlla l'SHA-256. Se la strada con le patch dalla versione
/// installata non riesce, riprova da capo con l'APK base piu' tutte le patch.
/// [forceFull] parte sempre dall'APK base (reinstallazione completa).
///
/// Se non riesce, [PatchRunResult.plainApkIsCurrent] dice se chi chiama puo'
/// scaricare l'APK completo della release: nelle release con sole patch quello
/// e' la base, non la build corrente, e va lasciato stare.
/// Lancia [PatchCancelledException] se annullato.
Future<PatchRunResult> runPatchPlan({
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
  // Release senza elenco delle patch: l'APK completo e' quello corrente.
  if (manifestUrl == null) {
    return const PatchRunResult.failed(plainApkIsCurrent: true);
  }

  Future<void> cleanUp() async {
    try {
      await _emptyDirectory(workDir);
    } catch (_) {}
  }

  PatchManifest? manifest;
  try {
    await _emptyDirectory(workDir);
    final manifestPath = '${workDir.path}/$kPatchManifestName';
    await download(manifestUrl, manifestPath, onBytes: (_) {});
    manifest = PatchManifest.tryParse(await File(manifestPath).readAsString());
  } on PatchCancelledException {
    await cleanUp();
    rethrow;
  } catch (e) {
    log?.call("elenco delle patch non scaricabile: $e");
    await cleanUp();
    return const PatchRunResult.failed(plainApkIsCurrent: false);
  }
  if (manifest == null) {
    log?.call('elenco delle patch non leggibile');
    await cleanUp();
    return const PatchRunResult.failed(plainApkIsCurrent: false);
  }
  final m = manifest;

  // Un tentativo: [full] parte dall'APK base, altrimenti da quello installato.
  // retry = true se vale la pena riprovare in un altro modo.
  Future<({String? path, bool retry})> attempt(bool full) async {
    try {
      await _emptyDirectory(workDir);
      final plan = planUpdate(m, installedBuild, forceFull: full);
      if (plan == null) {
        log?.call('nessuna strada con le patch dalla build $installedBuild');
        return (path: null, retry: false);
      }
      if (!plan.useBase) {
        // L'APK installato deve essere proprio quello da cui parte la patch.
        final sha = await sha256OfFile(installedApkPath!);
        if (sha != plan.edges.first.fromSha) {
          log?.call("l'APK installato non e' quello della build pubblicata");
          return (path: null, retry: true);
        }
      }

      final mb = (plan.downloadBytes / (1024 * 1024)).toStringAsFixed(1);
      if (plan.useBase) {
        log?.call('tipo: completa (parte dall\'APK base e applica '
            '${plan.edges.length} patch), da scaricare circa $mb MB, '
            'dalla build $installedBuild alla ${m.current.build}');
      } else {
        log?.call('tipo: patch (${plan.edges.length} '
            '${plan.edges.length == 1 ? "passo" : "passi"}), da scaricare '
            'circa $mb MB, dalla build $installedBuild alla ${m.current.build}');
      }

      final names = [
        if (plan.useBase) plan.base.asset,
        for (final e in plan.edges) e.asset,
      ];
      for (final n in names) {
        if (!assets.containsKey(n)) {
          log?.call('manca nella release: $n');
          return (path: null, retry: false);
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
        log?.call('scarico l\'APK base');
        await download(assets[plan.base.asset]!, basePath,
            expectedSize: plan.base.size, onBytes: bump);
        if (await sha256OfFile(basePath) != plan.base.sha256) {
          log?.call("l'APK base scaricato non coincide");
          await cleanUp();
          return (path: null, retry: false);
        }
        current = basePath;
        currentIsTemp = true;
      } else {
        current = installedApkPath!;
      }

      for (var i = 0; i < plan.edges.length; i++) {
        if (isCancelled?.call() ?? false) {
          throw const PatchCancelledException();
        }
        final edge = plan.edges[i];
        final patchPath = '${workDir.path}/patch-${edge.from}-${edge.to}.dpat';
        log?.call('scarico la patch ${i + 1} di ${plan.edges.length} '
            '(build ${edge.from} -> ${edge.to})');
        await download(assets[edge.asset]!, patchPath,
            expectedSize: edge.size, onBytes: bump);
        onProgress?.call(null);
        log?.call('applico la patch ${i + 1} di ${plan.edges.length} (ricostruisco l\'APK)');
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

      log?.call('APK ricostruito, controllo dell\'impronta in corso');
      if (await sha256OfFile(finalPath) != plan.target.sha256) {
        log?.call("l'APK ricostruito non coincide con quello pubblicato");
        await cleanUp();
        return (path: null, retry: true);
      }
      log?.call('APK ricostruito e controllato: aggiornamento pronto da installare');
      return (path: finalPath, retry: false);
    } on PatchCancelledException {
      await cleanUp();
      rethrow;
    } catch (e) {
      log?.call('patch non riuscita: $e');
      await cleanUp();
      return (path: null, retry: true);
    }
  }

  final startFull = forceFull || installedApkPath == null;
  var result = await attempt(startFull);
  if (result.path == null && result.retry && !startFull) {
    log?.call("riprovo da APK base e patch");
    result = await attempt(true);
  }
  final path = result.path;
  if (path != null) return PatchRunResult.ready(path);
  return PatchRunResult.failed(
    plainApkIsCurrent: m.base.build == m.current.build,
  );
}
