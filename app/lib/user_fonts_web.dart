import 'dart:js_interop';
import 'dart:typed_data';

import 'package:pdf_document/pdf_document.dart';
import 'package:web/web.dart' as web;

import 'idb_web.dart';
import 'user_fonts_model.dart';

/// Sul web i font importati stanno nel browser (IndexedDB), come sul telefono
/// stanno su disco: stessa funzione, stessa memoria (paletto 1).
const bool userFontsSupported = true;

const String _dbName = 'dart_pdf_editor_app.user_fonts';
const String _store = 'fonts';

Future<web.IDBDatabase>? _db;

Future<web.IDBObjectStore> _open(String mode) async {
  final db = await (_db ??= openIdb(_dbName, const [_store]));
  return db.transaction(_store.toJS, mode).objectStore(_store);
}

/// I font importati, per nome della famiglia. Il "percorso" e' il nome.
Future<List<UserFontFile>> loadUserFontFiles() async {
  try {
    final store = await _open('readonly');
    final keys = await idbRequest<List<String>>(
      store.getAllKeys(),
      (result) => [
        if (result != null)
          for (final v in (result as JSArray<JSAny?>).toDart)
            if (v != null) (v as JSString).toDart,
      ],
    );
    final fonts = [for (final k in keys) UserFontFile(family: k, path: k)];
    fonts.sort(
        (a, b) => a.family.toLowerCase().compareTo(b.family.toLowerCase()));
    return fonts;
  } catch (_) {
    return const []; // il browser non lascia salvare: nessun font importato
  }
}

Future<Uint8List?> readUserFontFile(String path) async {
  try {
    final store = await _open('readonly');
    return await idbRequest<Uint8List?>(
      store.get(path.toJS),
      (result) => result == null ? null : (result as JSUint8Array).toDart,
    );
  } catch (_) {
    return null;
  }
}

/// Stesse regole del telefono: una famiglia per file, solo la versione
/// normale, i file che non sono font si saltano.
Future<UserFontImportResult> importUserFontFiles(
    List<UserFontSource> files) async {
  final best = <String, ({UserFontSource source, String family})>{};
  var italic = 0;
  var invalid = 0;
  for (final file in files) {
    if (looksItalic(file.name)) {
      italic++;
      continue;
    }
    final String family;
    try {
      family = PdfEmbeddedFont.parse(file.bytes).displayName.trim();
    } catch (_) {
      invalid++;
      continue;
    }
    if (family.isEmpty) {
      invalid++;
      continue;
    }
    final key = family.toLowerCase();
    final previous = best[key];
    if (previous == null ||
        styleRank(file.name) < styleRank(previous.source.name)) {
      best[key] = (source: file, family: family);
    }
  }
  final existing = {
    for (final font in await loadUserFontFiles()) font.family.toLowerCase(),
  };
  final added = <String>[];
  var duplicates = 0;
  for (final entry in best.values) {
    if (existing.contains(entry.family.toLowerCase())) {
      duplicates++;
      continue;
    }
    try {
      final store = await _open('readwrite');
      final copy = Uint8List.fromList(entry.source.bytes);
      await idbRequest<void>(store.put(copy.toJS, entry.family.toJS), (_) {});
      added.add(entry.family);
    } catch (_) {
      invalid++;
    }
  }
  return UserFontImportResult(
    added: added,
    italic: italic,
    invalid: invalid,
    duplicates: duplicates,
  );
}

Future<void> deleteUserFontFile(String path) async {
  try {
    final store = await _open('readwrite');
    await idbRequest<void>(store.delete(path.toJS), (_) {});
  } catch (_) {}
}
