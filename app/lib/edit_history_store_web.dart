import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart'
    show PdfEditHistorySnapshot;
import 'package:web/web.dart' as web;

import 'edit_history_store_base.dart';
import 'idb_web.dart';

/// Quante cronologie si tengono: le piu' recenti, le altre si cancellano.
const int _kKeepHistories = 60;

const String _dbName = 'dart_pdf_editor_app.edit_history';
const String _metaStore = 'meta';
const String _tailStore = 'tails';

EditHistoryStore? openEditHistoryStore() => _IdbEditHistoryStore();

/// Cronologia annulla/ripeti nel browser (IndexedDB), come il file su disco
/// delle altre piattaforme: per ogni documento un indice JSON (lunghezze delle
/// revisioni, revisione corrente, ultimo uso) e, se c'e' qualcosa da ripetere,
/// i byte oltre la revisione corrente. La chiave e' `<lunghezza>-<sha256>`.
class _IdbEditHistoryStore implements EditHistoryStore {
  Future<web.IDBDatabase>? _db;

  Future<web.IDBObjectStore> _store(String name, String mode) async {
    final db = await (_db ??= openIdb(_dbName, const [_metaStore, _tailStore]));
    return db.transaction(name.toJS, mode).objectStore(name);
  }

  Future<String> _key(Uint8List bytes) async {
    // un attimo di respiro all'interfaccia prima di un calcolo lungo
    await Future<void>.delayed(Duration.zero);
    return '${bytes.length}-${sha256.convert(bytes)}';
  }

  String _encode(PdfEditHistorySnapshot snapshot) => jsonEncode({
        'r': snapshot.revisions,
        'c': snapshot.cursor,
        't': snapshot.tail.length,
        'u': DateTime.now().millisecondsSinceEpoch,
      });

  @override
  Future<PdfEditHistorySnapshot?> load(Uint8List bytes) async {
    try {
      final key = await _key(bytes);
      final meta = await _store(_metaStore, 'readonly');
      final text = await idbRequest<String?>(
        meta.get(key.toJS),
        (result) => result == null ? null : (result as JSString).toDart,
      );
      if (text == null) return null;
      final map = jsonDecode(text);
      if (map is! Map) return null;
      final revisions = [
        for (final r in (map['r'] as List)) (r as num).toInt(),
      ];
      final cursor = (map['c'] as num).toInt();
      final tailLength = (map['t'] as num).toInt();
      var tail = Uint8List(0);
      if (tailLength > 0) {
        final tails = await _store(_tailStore, 'readonly');
        final data = await idbRequest<Uint8List?>(
          tails.get(key.toJS),
          (result) =>
              result == null ? null : (result as JSUint8Array).toDart,
        );
        if (data == null || data.length != tailLength) return null;
        tail = data;
      }
      // La si e' usata: resta tra le piu' recenti.
      try {
        map['u'] = DateTime.now().millisecondsSinceEpoch;
        final touch = await _store(_metaStore, 'readwrite');
        await idbRequest<void>(touch.put(jsonEncode(map).toJS, key.toJS), (_) {});
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
      final key = await _key(bytes);
      // prima i byte da ripetere, poi l'indice: un indice senza i suoi byte
      // non esiste mai
      final tails = await _store(_tailStore, 'readwrite');
      if (snapshot.tail.isNotEmpty) {
        // copia dei byte: un pezzo di un buffer grande si salverebbe intero
        final copy = Uint8List.fromList(snapshot.tail);
        await idbRequest<void>(tails.put(copy.toJS, key.toJS), (_) {});
      } else {
        await idbRequest<void>(tails.delete(key.toJS), (_) {});
      }
      final meta = await _store(_metaStore, 'readwrite');
      await idbRequest<void>(
          meta.put(_encode(snapshot).toJS, key.toJS), (_) {});
      await _prune();
      return key;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      final meta = await _store(_metaStore, 'readwrite');
      await idbRequest<void>(meta.delete(key.toJS), (_) {});
      final tails = await _store(_tailStore, 'readwrite');
      await idbRequest<void>(tails.delete(key.toJS), (_) {});
    } catch (_) {}
  }

  Future<void> _prune() async {
    try {
      final store = await _store(_metaStore, 'readonly');
      // le due richieste partono insieme, prima di aspettarne una
      final keysFuture = idbRequest<List<String>>(store.getAllKeys(), (result) {
        if (result == null) return const [];
        return [
          for (final k in (result as JSArray<JSAny?>).toDart)
            (k! as JSString).toDart,
        ];
      });
      final valuesFuture = idbRequest<List<String>>(store.getAll(), (result) {
        if (result == null) return const [];
        return [
          for (final v in (result as JSArray<JSAny?>).toDart)
            (v! as JSString).toDart,
        ];
      });
      final keys = await keysFuture;
      final values = await valuesFuture;
      if (keys.length <= _kKeepHistories || keys.length != values.length) {
        return;
      }
      final used = <(String, int)>[];
      for (var i = 0; i < keys.length; i++) {
        var u = 0;
        try {
          final map = jsonDecode(values[i]);
          if (map is Map && map['u'] is num) u = (map['u'] as num).toInt();
        } catch (_) {}
        used.add((keys[i], u));
      }
      used.sort((a, b) => b.$2.compareTo(a.$2));
      for (final (key, _) in used.skip(_kKeepHistories)) {
        await remove(key);
      }
    } catch (_) {}
  }
}
