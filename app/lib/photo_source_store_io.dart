import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'pdf_cache_key.dart';

/// Quante foto si tengono: le piu' recenti, le altre si cancellano.
const int _kKeepPhotos = 20;

Future<Directory> _dir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}/photo_sources');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Ricorda [photo] come origine del PDF [pdfBytes]: un file
/// `<lunghezza>_<impronta>.photo` nella cartella privata dell'app.
Future<void> rememberPhotoSource(Uint8List pdfBytes, Uint8List photo) async {
  try {
    final dir = await _dir();
    final file = File('${dir.path}/${pdfContentKey(pdfBytes)}.photo');
    if (await file.exists()) {
      await file.setLastModified(DateTime.now());
    } else {
      await file.writeAsBytes(photo, flush: true);
    }
    await _prune(dir);
  } catch (_) {}
}

/// La foto da cui nasce il PDF [pdfBytes], o null se non c'e'.
Future<Uint8List?> recallPhotoSource(Uint8List pdfBytes) async {
  try {
    final dir = await _dir();
    // Nessuna foto con questa lunghezza: niente impronta da calcolare.
    final prefix = '${pdfBytes.length}_';
    var any = false;
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (name.startsWith(prefix) && name.endsWith('.photo')) {
        any = true;
        break;
      }
    }
    if (!any) return null;
    final file = File('${dir.path}/${pdfContentKey(pdfBytes)}.photo');
    if (!await file.exists()) return null;
    // La si e' usata: resta tra le piu' recenti.
    try {
      await file.setLastModified(DateTime.now());
    } catch (_) {}
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> _prune(Directory dir) async {
  try {
    final files = <(File, DateTime)>[];
    await for (final entry in dir.list()) {
      if (entry is File && entry.path.endsWith('.photo')) {
        files.add((entry, await entry.lastModified()));
      }
    }
    if (files.length <= _kKeepPhotos) return;
    files.sort((a, b) => b.$2.compareTo(a.$2));
    for (final (file, _) in files.skip(_kKeepPhotos)) {
      await file.delete();
    }
  } catch (_) {}
}
