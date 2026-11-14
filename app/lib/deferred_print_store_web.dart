import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'deferred_print.dart';
import 'idb_web.dart';

const String _dbName = 'dart_pdf_editor_app.deferred_print';
const String _metaStore = 'meta';
const String _dataStore = 'data';

/// Un solo archivio per tutta l'app: lo stesso oggetto serve a chi aggiunge e a
/// chi stampa.
final DeferredPrintStore _shared = _IdbDeferredPrintStore();

/// Archivio nel browser (IndexedDB): per ogni gruppo i fogli pronti (`data`) e
/// un indice JSON con nome e riepilogo (`meta`). I gruppi restano anche dopo
/// aver chiuso e riaperto la pagina. Se il browser non lascia usare
/// IndexedDB, i gruppi restano in memoria finche' la pagina e' aperta.
DeferredPrintStore openDeferredPrintStore() => _shared;

class _IdbDeferredPrintStore implements DeferredPrintStore {
  /// Dove finiscono i gruppi se IndexedDB non si puo' usare.
  final MemoryDeferredPrintStore _memory = MemoryDeferredPrintStore();

  Future<web.IDBDatabase>? _db;

  Future<web.IDBObjectStore> _store(String name, String mode) async {
    final db = await (_db ??= openIdb(_dbName, const [_metaStore, _dataStore]));
    return db.transaction(name.toJS, mode).objectStore(name);
  }

  List<String> _strings(JSAny? result) {
    if (result == null) return const [];
    return [
      for (final v in (result as JSArray<JSAny?>).toDart)
        if (v != null) (v as JSString).toDart,
    ];
  }

  @override
  Future<List<DeferredPrintItem>> list() async {
    final items = <String, DeferredPrintItem>{};
    try {
      final meta = await _store(_metaStore, 'readonly');
      final texts = await idbRequest<List<String>>(meta.getAll(), _strings);
      final data = await _store(_dataStore, 'readonly');
      final ids =
          (await idbRequest<List<String>>(data.getAllKeys(), _strings)).toSet();
      for (final text in texts) {
        final item = DeferredPrintItem.fromJson(text);
        if (item == null) continue;
        // un gruppo senza i suoi fogli non si puo' stampare: non si mostra
        if (!ids.contains(item.id)) continue;
        items[item.id] = item;
      }
    } catch (_) {
      // IndexedDB non disponibile: restano i gruppi in memoria.
    }
    for (final item in await _memory.list()) {
      items.putIfAbsent(item.id, () => item);
    }
    final result = items.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  @override
  Future<void> add(DeferredPrintItem item, Uint8List bytes) async {
    try {
      // prima i fogli, poi l'indice: un indice senza fogli non esiste mai
      // (copia dei byte: un pezzo di un buffer grande si salverebbe intero)
      final copy = Uint8List.fromList(bytes);
      final data = await _store(_dataStore, 'readwrite');
      await idbRequest<void>(data.put(copy.toJS, item.id.toJS), (_) {});
      final meta = await _store(_metaStore, 'readwrite');
      await idbRequest<void>(meta.put(item.toJson().toJS, item.id.toJS), (_) {});
    } catch (_) {
      // Spazio del browser esaurito o IndexedDB spento: il gruppo resta in
      // memoria finche' la pagina e' aperta, invece di perdersi.
      await _memory.add(item, bytes);
    }
  }

  @override
  Future<Uint8List?> read(String id) async {
    try {
      final data = await _store(_dataStore, 'readonly');
      final bytes = await idbRequest<Uint8List?>(
        data.get(id.toJS),
        (result) => result == null ? null : (result as JSUint8Array).toDart,
      );
      if (bytes != null) return bytes;
    } catch (_) {}
    return _memory.read(id);
  }

  @override
  Future<void> rename(String id, String name) async {
    try {
      final meta = await _store(_metaStore, 'readonly');
      final text = await idbRequest<String?>(
        meta.get(id.toJS),
        (result) => result == null ? null : (result as JSString).toDart,
      );
      if (text != null) {
        final item = DeferredPrintItem.fromJson(text);
        if (item != null) {
          final write = await _store(_metaStore, 'readwrite');
          await idbRequest<void>(
              write.put(item.copyWith(name: name).toJson().toJS, id.toJS),
              (_) {});
        }
      }
    } catch (_) {}
    await _memory.rename(id, name);
  }

  @override
  Future<void> remove(String id) async {
    try {
      final meta = await _store(_metaStore, 'readwrite');
      await idbRequest<void>(meta.delete(id.toJS), (_) {});
      final data = await _store(_dataStore, 'readwrite');
      await idbRequest<void>(data.delete(id.toJS), (_) {});
    } catch (_) {}
    await _memory.remove(id);
  }
}
