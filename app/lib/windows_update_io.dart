import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_log.dart';
import 'update_installer.dart'
    show UpdateCancelledException, UpdateInstallException;
import 'windows_files.dart';

/// Aggiorna l'app Windows scaricando solo i file cambiati.
///
/// Legge l'elenco dei file della build nuova, calcola l'SHA-256 dei file che ci
/// sono gia' nella cartella dell'app e scarica (compressi, uno per uno) solo
/// quelli che mancano o sono diversi. Ogni file viene decompresso e controllato
/// in una cartella temporanea. Poi parte uno script che aspetta la chiusura
/// dell'app, copia i file nuovi sopra quelli vecchi e riapre l'app: niente
/// installer, niente zip.
///
/// Se tutti i file sono gia' aggiornati ritorna senza fare niente; altrimenti
/// l'app si chiude da sola (la funzione non ritorna). Lancia
/// [UpdateCancelledException] se l'utente annulla e [UpdateInstallException]
/// negli altri errori.
Future<void> applyWindowsFilesUpdate({
  required Map<String, String> assets,
  required Map<String, int> assetSizes,
  required bool Function() isCancelled,
  required WindowsUpdateProgress onProgress,
  http.Client Function()? clientFactory,
}) async {
  if (!Platform.isWindows) {
    throw const UpdateInstallException(
        "Questo aggiornamento e' solo per Windows");
  }
  final manifestUrl = assets[kWindowsFilesManifestName];
  if (manifestUrl == null) {
    throw const UpdateInstallException(
        "Nella release manca l'elenco dei file di Windows");
  }
  final exePath = Platform.resolvedExecutable;
  final installDir = File(exePath).parent;
  await _checkWritable(installDir);

  final temp = await getTemporaryDirectory();
  final staging = Directory(_join(temp.path, 'dartpdf-update-files'));
  final client = (clientFactory ?? http.Client.new)();
  try {
    onProgress(null, "leggo l'elenco dei file");
    final manifestBytes = await _fetchBytes(client, manifestUrl,
        isCancelled: isCancelled, expected: assetSizes[kWindowsFilesManifestName]);
    final manifest = WindowsFilesManifest.tryParse(utf8.decode(manifestBytes));
    if (manifest == null || manifest.files.isEmpty) {
      throw const UpdateInstallException(
          "L'elenco dei file di Windows non e' valido");
    }

    // Cosa c'e' gia' nella cartella dell'app.
    final local = <String, String?>{};
    for (var i = 0; i < manifest.files.length; i++) {
      if (isCancelled()) throw const UpdateCancelledException();
      final f = manifest.files[i];
      onProgress(null, 'controllo i file (${i + 1}/${manifest.files.length})');
      local[f.path] = await _sha256Of(File(_join(installDir.path, f.path)));
    }
    final needed = windowsFilesToDownload(manifest, local);
    if (needed.isEmpty) {
      AppLog.instance
          .info('Aggiornamenti', 'Windows: tutti i file sono gia aggiornati');
      return;
    }
    final byHash = windowsDownloadsByHash(needed);

    await _deleteQuietly(staging);
    await staging.create(recursive: true);

    var totalBytes = 0;
    for (final hash in byHash.keys) {
      totalBytes += assetSizes['$hash.gz'] ?? 0;
    }
    var doneBytes = 0;
    var index = 0;
    for (final entry in byHash.entries) {
      if (isCancelled()) throw const UpdateCancelledException();
      index++;
      final hash = entry.key;
      final name = '$hash.gz';
      final label = entry.value.first.path.split('/').last;
      final url = assets[name];
      if (url == null) {
        throw UpdateInstallException(
            'Nella release manca il file ${entry.value.first.path}');
      }
      final packed = await _fetchBytes(
        client,
        url,
        expected: assetSizes[name],
        isCancelled: isCancelled,
        onChunk: (received) {
          final fraction =
              totalBytes > 0 ? (doneBytes + received) / totalBytes : null;
          onProgress(fraction, 'scarico $label ($index/${byHash.length})');
        },
      );
      doneBytes += packed.length;
      final Uint8List data;
      try {
        data = Uint8List.fromList(gzip.decode(packed));
      } catch (_) {
        throw UpdateInstallException('Il file $label e danneggiato');
      }
      if (sha256.convert(data).toString() != hash) {
        throw UpdateInstallException(
            'Il file $label non corrisponde al codice atteso');
      }
      for (final f in entry.value) {
        final out = File(_join(staging.path, f.path));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(data, flush: true);
      }
    }

    onProgress(1, "preparo l'installazione");
    final script = File(_join(temp.path, 'dartpdf-apply-update.bat'));
    await script.writeAsString(
      buildWindowsApplyScript(
        pid: pid,
        stagingDir: staging.path,
        installDir: installDir.path,
        exePath: exePath,
      ),
      flush: true,
    );
    AppLog.instance.info('Aggiornamenti',
        'Windows: scaricati ${byHash.length} file, riavvio per applicarli');
    onProgress(1, "riavvio l'app");
    await _startScriptHidden(script.path);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    exit(0);
  } catch (_) {
    await _deleteQuietly(staging);
    rethrow;
  } finally {
    client.close();
  }
}

/// Avvia lo script di aggiornamento senza finestra: con PowerShell, che apre
/// il prompt dei comandi nascosto. Se PowerShell non parte, ripiega sul
/// prompt visibile (meglio una finestra che un aggiornamento che non parte).
Future<void> _startScriptHidden(String scriptPath) async {
  try {
    final quoted = scriptPath.replaceAll("'", "''");
    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-Command',
        "Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' "
            "-ArgumentList '/c','\"$quoted\"'",
      ],
      mode: ProcessStartMode.detached,
    );
  } catch (_) {
    await Process.start('cmd.exe', ['/c', scriptPath],
        mode: ProcessStartMode.detached);
  }
}

String _join(String dir, String relative) {
  final sep = Platform.pathSeparator;
  final fixed = relative.replaceAll('/', sep);
  return dir.endsWith(sep) ? '$dir$fixed' : '$dir$sep$fixed';
}

/// L'SHA-256 del file, o null se non c'e' o non si riesce a leggerlo.
Future<String?> _sha256Of(File file) async {
  try {
    if (!await file.exists()) return null;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  } on FileSystemException {
    return null;
  }
}

/// Prova a scrivere nella cartella dell'app: senza permesso (per esempio in
/// Program Files) l'aggiornamento a file non puo' funzionare.
Future<void> _checkWritable(Directory dir) async {
  final probe = File(_join(dir.path, '.dartpdf-write-test'));
  try {
    await probe.writeAsString('x', flush: true);
    await probe.delete();
  } on FileSystemException {
    throw UpdateInstallException(
        "La cartella dell'app (${dir.path}) non e' scrivibile: scarica lo "
        'zip e sostituisci la cartella a mano');
  }
}

Future<void> _deleteQuietly(Directory dir) async {
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    // Una cartella temporanea che resta non e' un problema.
  }
}

/// Scarica con nuovi tentativi: GitHub risponde ogni tanto con un errore
/// momentaneo. Non si riprova per un annullamento o un errore 4xx.
Future<Uint8List> _fetchBytes(
  http.Client client,
  String url, {
  int? expected,
  required bool Function() isCancelled,
  void Function(int received)? onChunk,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') {
    throw const UpdateInstallException(
        "Rifiuto di scaricare un aggiornamento da un indirizzo non sicuro");
  }
  const attempts = 4;
  for (var attempt = 1;; attempt++) {
    try {
      final response = await client.send(http.Request('GET', uri));
      if (response.statusCode >= 500) {
        throw Exception('HTTP ${response.statusCode}');
      }
      if (response.statusCode != 200) {
        throw UpdateInstallException(
            'Download non riuscito (HTTP ${response.statusCode})');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (isCancelled()) throw const UpdateCancelledException();
        builder.add(chunk);
        onChunk?.call(builder.length);
      }
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) throw Exception('file vuoto');
      if (expected != null && bytes.length != expected) {
        throw Exception('file incompleto (${bytes.length} di $expected byte)');
      }
      return bytes;
    } on UpdateCancelledException {
      rethrow;
    } on UpdateInstallException {
      rethrow;
    } catch (e) {
      if (attempt >= attempts) {
        throw UpdateInstallException('Download non riuscito: $e');
      }
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
      if (isCancelled()) throw const UpdateCancelledException();
    }
  }
}
