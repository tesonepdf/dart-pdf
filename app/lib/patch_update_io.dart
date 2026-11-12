import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_log.dart';
import 'dpat_apply.dart';
import 'patch_manifest.dart';
import 'patch_runner_io.dart';
import 'update_installer.dart' show UpdateCancelledException;

const MethodChannel _updateChannel = MethodChannel('dev.milanko.dartpdf/update');

/// Prepara l'APK della build corrente con le patch (vedi [runPatchPlan]) nella
/// cartella degli aggiornamenti dell'app. Se non riesce, l'esito dice se
/// l'APK completo della release e' la build corrente (allora si puo' scaricare)
/// o una base piu' vecchia (allora no). [forceFull] riparte dall'APK base
/// (ripristino). Lancia [UpdateCancelledException] se l'utente annulla.
Future<PatchRunResult> buildPatchedApk({
  required Map<String, String> assets,
  required int installedBuild,
  bool forceFull = false,
  void Function(double? fraction)? onProgress,
  bool Function()? isCancelled,
  http.Client Function()? clientFactory,
}) async {
  if (!assets.containsKey(kPatchManifestName)) {
    return const PatchRunResult.failed(plainApkIsCurrent: true);
  }
  final factory = clientFactory ?? http.Client.new;
  try {
    String? installed;
    try {
      installed = await _updateChannel.invokeMethod<String>('installedApkPath');
    } catch (_) {
      installed = null;
    }
    final temp = await getTemporaryDirectory();
    // Android installa solo da questa cartella (vedi MainActivity.installUpdateApk).
    final dir = Directory('${temp.path}/updates');
    return await runPatchPlan(
      assets: assets,
      installedBuild: installedBuild,
      installedApkPath: installed,
      workDir: dir,
      forceFull: forceFull,
      onProgress: onProgress,
      isCancelled: isCancelled,
      log: (m) {
        debugPrint('Aggiornamento con patch: $m');
        AppLog.instance.info('Aggiornamenti', m);
      },
      download: (url, path, {expectedSize, required onBytes}) =>
          _downloadToFile(factory, url, path,
              expectedSize: expectedSize,
              onBytes: onBytes,
              isCancelled: isCancelled),
    );
  } on PatchCancelledException {
    throw const UpdateCancelledException();
  } catch (e) {
    debugPrint('Aggiornamento con patch non riuscito: $e');
    AppLog.instance.error('Aggiornamenti', 'Aggiornamento con patch non riuscito: $e');
    // Non si sa com'e' fatta la release: meglio non installare un APK che
    // potrebbe essere una base piu' vecchia.
    return const PatchRunResult.failed(plainApkIsCurrent: false);
  }
}

/// Scarica [url] in [path] a blocchi, con nuovi tentativi per gli errori
/// temporanei (rete, 5xx).
Future<void> _downloadToFile(
  http.Client Function() factory,
  String url,
  String path, {
  int? expectedSize,
  required void Function(int bytes) onBytes,
  bool Function()? isCancelled,
}) async {
  final uri = Uri.parse(url);
  if (uri.scheme != 'https') {
    throw const PatchFormatException('indirizzo non sicuro');
  }
  const attempts = 5;
  for (var attempt = 1;; attempt++) {
    var counted = 0;
    final client = factory();
    try {
      final response = await client.send(http.Request('GET', uri));
      if (response.statusCode >= 500) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      if (response.statusCode != 200) {
        throw PatchFormatException(
            'download non riuscito (HTTP ${response.statusCode})');
      }
      final sink = File(path).openWrite();
      try {
        await for (final chunk in response.stream) {
          if (isCancelled?.call() ?? false) {
            throw const PatchCancelledException();
          }
          sink.add(chunk);
          counted += chunk.length;
          onBytes(chunk.length);
        }
      } finally {
        await sink.close();
      }
      if (expectedSize != null && counted != expectedSize) {
        throw HttpException('download incompleto ($counted di $expectedSize)');
      }
      return;
    } on PatchCancelledException {
      rethrow;
    } on PatchFormatException {
      rethrow;
    } catch (e) {
      onBytes(-counted);
      if (attempt >= attempts) {
        throw PatchFormatException('download non riuscito: $e');
      }
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    } finally {
      client.close();
    }
  }
}
