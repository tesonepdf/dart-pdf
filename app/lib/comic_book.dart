import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show compute;

// Fumetti .cbz: un file zip con una pagina per immagine. Si leggono le
// immagini nell'ordine dei nomi (pagina2 prima di pagina10) e si fa un PDF con
// una pagina per immagine, che si apre in una scheda nuova. Solo logica e
// scelta del file: il PDF lo scrive `photosToPdfAsync` (pdf_conversions.dart)
// e il collegamento al menu è in `editor_screen.dart`.

/// I file che si scelgono per aprire un fumetto.
XTypeGroup comicTypeGroup() => const XTypeGroup(
      label: 'Fumetti (.cbz)',
      extensions: ['cbz', 'zip'],
      mimeTypes: ['application/vnd.comicbook+zip', 'application/zip'],
      uniformTypeIdentifiers: ['public.data'],
    );

/// Chiede un file .cbz, o null se si annulla.
Future<XFile?> pickComicFile() =>
    openFile(acceptedTypeGroups: [comicTypeGroup()]);

const _imageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'];

/// Vero se [name] è un'immagine da tenere: ha un'estensione di immagine e non
/// è un file nascosto o di servizio (`__MACOSX/`, `.DS_Store`, `Thumbs.db`).
bool isComicImageName(String name) {
  final parts = name.replaceAll('\\', '/').split('/');
  if (parts.any((p) => p.startsWith('.') || p == '__MACOSX')) return false;
  final dot = parts.last.lastIndexOf('.');
  if (dot < 0) return false;
  return _imageExtensions.contains(parts.last.substring(dot + 1).toLowerCase());
}

/// Confronto "naturale" dei nomi: i numeri si confrontano come numeri, quindi
/// `pag2.jpg` viene prima di `pag10.jpg`. Le maiuscole non contano.
int naturalCompare(String a, String b) {
  final ta = _tokens(a.toLowerCase());
  final tb = _tokens(b.toLowerCase());
  for (var i = 0; i < ta.length && i < tb.length; i++) {
    final x = ta[i];
    final y = tb[i];
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    final c = (nx != null && ny != null) ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  return ta.length.compareTo(tb.length);
}

List<String> _tokens(String s) =>
    RegExp(r'\d+|\D+').allMatches(s).map((m) => m.group(0)!).toList();

/// Le immagini di un .cbz, nell'ordine dei nomi. Lancia [FormatException] se
/// non è uno zip o se dentro non ci sono immagini.
List<Uint8List> comicImages(Uint8List cbz) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(cbz);
  } catch (_) {
    throw const FormatException('non è un file .cbz leggibile');
  }
  final files = [
    for (final f in archive.files)
      if (f.isFile && isComicImageName(f.name)) f,
  ]..sort((a, b) => naturalCompare(a.name, b.name));
  if (files.isEmpty) {
    throw const FormatException('nel fumetto non ci sono immagini');
  }
  return [for (final f in files) Uint8List.fromList(f.content as List<int>)];
}

/// [comicImages] fuori dal filo dell'interfaccia: aprire uno zip grande è
/// lento.
Future<List<Uint8List>> comicImagesAsync(Uint8List cbz) =>
    compute(comicImages, cbz, debugLabel: 'comic images');

/// Il titolo della scheda: il nome del file senza `.cbz` (o `.zip`), più
/// `.pdf`.
String comicTitle(String fileName) {
  var stem = fileName.trim();
  final lower = stem.toLowerCase();
  if (lower.endsWith('.cbz') || lower.endsWith('.zip')) {
    stem = stem.substring(0, stem.length - 4).trim();
  }
  if (stem.isEmpty) stem = 'fumetto';
  return '$stem.pdf';
}
