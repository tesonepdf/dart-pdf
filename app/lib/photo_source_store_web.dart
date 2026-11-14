import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'idb_web.dart';
import 'pdf_cache_key.dart';

/// Quante foto si tengono: le piu' recenti, le altre si cancellano.
const int _kKeepPhotos = 20;

const String _dbName = 'dart_pdf_editor_app.photo_sources';
const String _photoStore = 'photos';
const String _metaStore = 'meta';

Future<web.IDBDatabase>? _db;

Future<web.IDBObjectStore> _store(String name, String mode) async {
  final db = await (_db ??= openIdb(_dbName, const [_photoStore, _metaStore]));
  return db.transaction(name.toJS, mode).objectStore(name);
}

List<String> _strings(JSAny? result) {
  if (result == null) return const [];
  return [
    for (final v in (result as JSArray<JSAny?>).toDart)
      if (v != null) (v as JSString).toDart,
  ];
}

Future<void> _touch(String key) async {
  final meta = await _store(_metaStore, 'readwrite');
  await idbRequest<void>(
      meta.put('${DateTime.now().millisecondsSinceEpoch}'.toJS, key.toJS),
      (_) {});
}

/// Ricorda [photo] come origine del PDF [pdfBytes] (IndexedDB, chiave
/// `<lunghezza>_<impronta>`).
Future<void> rememberPhotoSource(Uint8List pdfBytes, Uint8List photo) async {
  try {
    final key = pdfContentKey(pdfBytes);
    final photos = await _store(_photoStore, 'readwrite');
    // copia dei byte: un pezzo di un buffer grande si salverebbe intero
    final copy = Uint8List.fromList(photo);
    await idbRequest<void>(photos.put(copy.toJS, key.toJS), (_) {});
    await _touch(key);
    await _prune();
  } catch (_) {}
}

/// La foto da cui nasce il PDF [pdfBytes], o null se non c'e'.
Future<Uint8List?> recallPhotoSource(Uint8List pdfBytes) async {
  try {
    // Nessuna foto con questa lunghezza: niente impronta da calcolare.
    final photos = await _store(_photoStore, 'readonly');
    final keys = await idbRequest<List<String>>(photos.getAllKeys(), _strings);
    final prefix = '${pdfBytes.length}_';
    if (!keys.any((k) => k.startsWith(prefix))) return null;
    final key = pdfContentKey(pdfBytes);
    if (!keys.contains(key)) return null;
    final read = await _store(_photoStore, 'readonly');
    final bytes = await idbRequest<Uint8List?>(
      read.get(key.toJS),
      (result) => result == null ? null : (result as JSUint8Array).toDart,
    );
    if (bytes == null) return null;
    try {
      await _touch(key);
    } catch (_) {}
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<void> _prune() async {
  try {
    final meta = await _store(_metaStore, 'readonly');
    // le due richieste partono insieme, prima di aspettarne una
    final keysFuture = idbRequest<List<String>>(meta.getAllKeys(), _strings);
    final valuesFuture = idbRequest<List<String>>(meta.getAll(), _strings);
    final keys = await keysFuture;
    final values = await valuesFuture;
    if (keys.length <= _kKeepPhotos || keys.length != values.length) return;
    final used = <(String, int)>[
      for (var i = 0; i < keys.length; i++)
        (keys[i], int.tryParse(values[i]) ?? 0),
    ];
    used.sort((a, b) => b.$2.compareTo(a.$2));
    for (final (key, _) in used.skip(_kKeepPhotos)) {
      final m = await _store(_metaStore, 'readwrite');
      await idbRequest<void>(m.delete(key.toJS), (_) {});
      final p = await _store(_photoStore, 'readwrite');
      await idbRequest<void>(p.delete(key.toJS), (_) {});
    }
  } catch (_) {}
}
