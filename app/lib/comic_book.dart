import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:pdf_document/pdf_document.dart';

import 'pdf_conversions.dart';

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

// --- Capitoli, informazioni del fumetto e PDF a pezzi -----------------------

/// Un capitolo del fumetto: il titolo e la prima pagina (da 0) del PDF.
typedef ComicChapter = ({String title, int page});

/// Le informazioni di `ComicInfo.xml` che servono: titolo, serie e numero.
typedef ComicInfo = ({String title, String series, String number});

String _unescapeXml(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

String _xmlTag(String xml, String tag) {
  final m = RegExp('<$tag>([^<]*)</$tag>', caseSensitive: false).firstMatch(xml);
  return m == null ? '' : _unescapeXml(m.group(1)!).trim();
}

/// Legge titolo, serie e numero da un `ComicInfo.xml`. Un campo mancante
/// resta vuoto.
ComicInfo parseComicInfo(String xml) => (
      title: _xmlTag(xml, 'Title'),
      series: _xmlTag(xml, 'Series'),
      number: _xmlTag(xml, 'Number'),
    );

/// Il titolo della scheda dalle informazioni del fumetto: "Serie 3 - Titolo".
/// Senza serie né titolo si usa il nome del file ([comicTitle]).
String comicTitleFor(String fileName, ComicInfo? info) {
  if (info == null || (info.title.isEmpty && info.series.isEmpty)) {
    return comicTitle(fileName);
  }
  final head = [info.series, info.number].where((p) => p.isNotEmpty).join(' ');
  final name = [head, info.title].where((p) => p.isNotEmpty).join(' - ');
  final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
  return clean.isEmpty ? comicTitle(fileName) : '$clean.pdf';
}

/// Per ogni immagine (nomi già in ordine) il capitolo a cui appartiene, o
/// null se sta fuori da ogni cartella. Si tolgono le cartelle che hanno tutte
/// le immagini in comune (un cartellone unico dentro lo zip), poi la cartella
/// che resta è il capitolo. Con una sola cartella di capitolo, o nessuna, non
/// ci sono capitoli.
List<String?> comicChapterNames(List<String> sortedNames) {
  final dirs = [
    for (final n in sortedNames)
      (n.replaceAll('\\', '/').split('/')..removeLast()),
  ];
  if (dirs.isEmpty) return const [];
  var common = 0;
  while (dirs.every((d) => d.length > common) &&
      dirs.every((d) => d[common] == dirs.first[common])) {
    common++;
  }
  final names = [
    for (final d in dirs) d.length > common ? d.sublist(common).join(' / ') : null,
  ];
  final distinct = names.whereType<String>().toSet();
  if (distinct.length < 2) return [for (final _ in names) null];
  return names;
}

/// Il risultato di [comicToPdf].
typedef ComicPdfResult = ({
  Uint8List bytes,
  int pages,
  int skipped,
  List<ComicChapter> chapters,
  ComicInfo? info,
});

const _mergeEvery = 40;

/// Dal file .cbz al PDF: una pagina per immagine, nell'ordine dei nomi, con i
/// capitoli come segnalibri. Si lavora un'immagine alla volta e i PDF
/// parziali si uniscono ogni [_mergeEvery] pagine, così in memoria non stanno
/// insieme tutte le immagini decodificate. Lancia [FormatException] se non è
/// uno zip, se non ha immagini o se nessuna si legge.
ComicPdfResult comicToPdf(Uint8List cbz) {
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
  ComicInfo? info;
  for (final f in archive.files) {
    final base = f.name.replaceAll('\\', '/').split('/').last.toLowerCase();
    if (f.isFile && base == 'comicinfo.xml') {
      try {
        info = parseComicInfo(utf8.decode(f.content as List<int>,
            allowMalformed: true));
      } catch (_) {}
      break;
    }
  }
  final chapterOf = comicChapterNames([for (final f in files) f.name]);
  final partials = <Uint8List>[];
  final pending = <Uint8List>[];
  final chapters = <ComicChapter>[];
  String? lastChapter;
  var pages = 0;
  var skipped = 0;
  for (var i = 0; i < files.length; i++) {
    final bytes = Uint8List.fromList(files[i].content as List<int>);
    final PhotosPdfResult one;
    try {
      one = photosToPdf([bytes], PhotoPdfPage.photoSize);
    } on FormatException {
      skipped++;
      continue;
    }
    if (one.pages == 0) {
      skipped++;
      continue;
    }
    final chapter = chapterOf[i];
    if (chapter != null && chapter != lastChapter) {
      chapters.add((title: chapter, page: pages));
      lastChapter = chapter;
    }
    pending.add(one.bytes);
    pages++;
    if (pending.length >= _mergeEvery) {
      partials.add(PdfMerger.merge(List.of(pending)));
      pending.clear();
    }
  }
  if (pending.isNotEmpty) {
    partials.add(pending.length == 1 ? pending.single : PdfMerger.merge(pending));
  }
  if (partials.isEmpty) {
    throw const FormatException('nessuna immagine leggibile');
  }
  var out = partials.length == 1 ? partials.single : PdfMerger.merge(partials);
  if (chapters.length >= 2) {
    final editor = PdfEditor(PdfDocument.open(out));
    for (final c in chapters) {
      editor.addOutlineItem(c.title, pageIndex: c.page);
    }
    out = editor.save();
  }
  return (
    bytes: out,
    pages: pages,
    skipped: skipped,
    chapters: chapters.length >= 2 ? chapters : const [],
    info: info,
  );
}

/// [comicToPdf] fuori dal filo dell'interfaccia.
Future<ComicPdfResult> comicToPdfAsync(Uint8List cbz) =>
    compute(comicToPdf, cbz, debugLabel: 'comic to PDF');
