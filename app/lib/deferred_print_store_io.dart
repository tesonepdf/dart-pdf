import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'deferred_print.dart';

/// Un solo archivio per tutta l'app: lo stesso oggetto serve a chi aggiunge e a
/// chi stampa.
final DeferredPrintStore _shared = _FileDeferredPrintStore();

/// Archivio su file: per ogni gruppo un `<id>.pdf` (i fogli pronti) e un
/// `<id>.json` (nome e riepilogo), nella cartella privata dell'app.
DeferredPrintStore openDeferredPrintStore() => _shared;

class _FileDeferredPrintStore implements DeferredPrintStore {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/deferred_print');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  File _data(Directory dir, String id) => File('${dir.path}/$id.pdf');
  File _meta(Directory dir, String id) => File('${dir.path}/$id.json');

  @override
  Future<List<DeferredPrintItem>> list() async {
    try {
      final dir = await _dir();
      final items = <DeferredPrintItem>[];
      await for (final entry in dir.list()) {
        if (entry is! File || !entry.path.endsWith('.json')) continue;
        final item = DeferredPrintItem.fromJson(await entry.readAsString());
        if (item == null) continue;
        // un gruppo senza i suoi fogli non si puo' stampare: non si mostra
        if (!await _data(dir, item.id).exists()) continue;
        items.add(item);
      }
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> add(DeferredPrintItem item, Uint8List bytes) async {
    final dir = await _dir();
    // prima i fogli, poi l'indice: un indice senza fogli non esiste mai
    await _data(dir, item.id).writeAsBytes(bytes, flush: true);
    await _meta(dir, item.id).writeAsString(item.toJson(), flush: true);
  }

  @override
  Future<Uint8List?> read(String id) async {
    try {
      final data = _data(await _dir(), id);
      if (!await data.exists()) return null;
      return await data.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> rename(String id, String name) async {
    try {
      final dir = await _dir();
      final file = _meta(dir, id);
      if (!await file.exists()) return;
      final item = DeferredPrintItem.fromJson(await file.readAsString());
      if (item == null) return;
      await file.writeAsString(item.copyWith(name: name).toJson(), flush: true);
    } catch (_) {}
  }

  @override
  Future<void> remove(String id) async {
    try {
      final dir = await _dir();
      final meta = _meta(dir, id);
      final data = _data(dir, id);
      if (await meta.exists()) await meta.delete();
      if (await data.exists()) await data.delete();
    } catch (_) {}
  }
}
