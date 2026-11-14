import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart'
    show PdfEditHistorySnapshot;
import 'package:flutter/foundation.dart' show compute;
import 'package:path_provider/path_provider.dart';

import 'edit_history_store_base.dart';

/// Quante cronologie si tengono: le piu' recenti, le altre si cancellano.
const int _kKeepHistories = 60;

String _sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();

EditHistoryStore? openEditHistoryStore() => _FileEditHistoryStore();

/// Per ogni documento un `<lunghezza>-<sha256>.json` (lunghezze delle
/// revisioni e revisione corrente) e, se c'e' qualcosa da ripetere, un
/// `<lunghezza>-<sha256>.tail` con i byte oltre la revisione corrente.
class _FileEditHistoryStore implements EditHistoryStore {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/edit_history');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  File _meta(Directory dir, String key) => File('${dir.path}/$key.json');
  File _tail(Directory dir, String key) => File('${dir.path}/$key.tail');

  Future<String> _key(Uint8List bytes) async {
    final hash = await compute(_sha256Hex, bytes);
    return '${bytes.length}-$hash';
  }

  @override
  Future<PdfEditHistorySnapshot?> load(Uint8List bytes) async {
    try {
      final dir = await _dir();
      final prefix = '${bytes.length}-';
      var any = false;
      await for (final entry in dir.list()) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        if (name.startsWith(prefix) && name.endsWith('.json')) {
          any = true;
          break;
        }
      }
      // Nessuna cronologia con questa lunghezza: niente impronta da calcolare.
      if (!any) return null;
      final key = await _key(bytes);
      final meta = _meta(dir, key);
      if (!await meta.exists()) return null;
      final map = jsonDecode(await meta.readAsString());
      if (map is! Map) return null;
      final revisions = [
        for (final r in (map['r'] as List)) (r as num).toInt(),
      ];
      final cursor = (map['c'] as num).toInt();
      final tailLength = (map['t'] as num).toInt();
      var tail = Uint8List(0);
      if (tailLength > 0) {
        final file = _tail(dir, key);
        if (!await file.exists()) return null;
        tail = await file.readAsBytes();
        if (tail.length != tailLength) return null;
      }
      // La si e' usata: resta tra le piu' recenti.
      try {
        await meta.setLastModified(DateTime.now());
      } catch (_) {}
      return PdfEditHistorySnapshot(
          revisions: revisions, cursor: cursor, tail: tail);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> save(Uint8List bytes, PdfEditHistorySnapshot snapshot) async {
    try {
      final dir = await _dir();
      final key = await _key(bytes);
      final tail = _tail(dir, key);
      // prima i byte da ripetere, poi l'indice: un indice senza i suoi byte
      // non esiste mai
      if (snapshot.tail.isNotEmpty) {
        await tail.writeAsBytes(snapshot.tail, flush: true);
      } else if (await tail.exists()) {
        await tail.delete();
      }
      await _meta(dir, key).writeAsString(
        jsonEncode({
          'r': snapshot.revisions,
          'c': snapshot.cursor,
          't': snapshot.tail.length,
        }),
        flush: true,
      );
      await _prune(dir);
      return key;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      final dir = await _dir();
      final meta = _meta(dir, key);
      final tail = _tail(dir, key);
      if (await meta.exists()) await meta.delete();
      if (await tail.exists()) await tail.delete();
    } catch (_) {}
  }

  Future<void> _prune(Directory dir) async {
    try {
      final metas = <(File, DateTime)>[];
      await for (final entry in dir.list()) {
        if (entry is File && entry.path.endsWith('.json')) {
          metas.add((entry, await entry.lastModified()));
        }
      }
      if (metas.length <= _kKeepHistories) return;
      metas.sort((a, b) => b.$2.compareTo(a.$2));
      for (final (file, _) in metas.skip(_kKeepHistories)) {
        final base = file.path.substring(0, file.path.length - 5);
        await file.delete();
        final tail = File('$base.tail');
        if (await tail.exists()) await tail.delete();
      }
    } catch (_) {}
  }
}
